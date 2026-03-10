import modal
from fastapi import FastAPI, UploadFile, File
import io
import time
import os


# --- Funkcja budująca: chmura POBIERA modele bazowe ---
def download_models():
    import torch
    from transformers import Qwen2VLProcessor, Qwen2VLForConditionalGeneration
    from transformers import PaliGemmaProcessor, PaliGemmaForConditionalGeneration

    print("[*] Pobieranie Qwen2-VL...")
    qwen_id = "Qwen/Qwen2-VL-2B-Instruct"
    Qwen2VLProcessor.from_pretrained(qwen_id)
    Qwen2VLForConditionalGeneration.from_pretrained(qwen_id, torch_dtype=torch.bfloat16)

    print("[*] Pobieranie PaliGemma-3B (wymaga tokenu HF)...")
    paligemma_id = "google/paligemma-3b-pt-224"
    hf_token = os.environ.get("HF_TOKEN")
    PaliGemmaProcessor.from_pretrained(paligemma_id, token=hf_token)
    PaliGemmaForConditionalGeneration.from_pretrained(paligemma_id, torch_dtype=torch.bfloat16, token=hf_token)


# 1. Środowisko (Dodajemy sekret z HF!)
image = (
    modal.Image.debian_slim()
    .pip_install(
        "fastapi[standard]", "torch", "torchvision", "transformers>=4.46.0",
        "pillow", "python-multipart", "peft", "qwen-vl-utils", "accelerate"
    )
    .run_function(download_models, secrets=[modal.Secret.from_name("huggingface")])
)

# 2. Rezerwujemy DYSKI
wolumen_paragonow = modal.Volume.from_name("archiwum-paragonow", create_if_missing=True)
wolumen_qwen = modal.Volume.from_name("model-v3-wolumen")
wolumen_paligemma = modal.Volume.from_name("model-paligemma-wolumen")

app = modal.App("ksiegowy-ai-dual")
web_app = FastAPI()


# ==========================================
# 🧠 SILNIK 1: QWEN 2 VL
# ==========================================
@app.cls(image=image, gpu="T4", volumes={"/zapisane_paragony": wolumen_paragonow, "/model_v3": wolumen_qwen})
class QwenModel:
    @modal.enter()
    def start_maszyny(self):
        import torch
        from transformers import Qwen2VLProcessor, Qwen2VLForConditionalGeneration
        from peft import PeftModel

        model_id = "Qwen/Qwen2-VL-2B-Instruct"
        self.processor = Qwen2VLProcessor.from_pretrained(model_id, min_pixels=256 * 28 * 28, max_pixels=1024 * 28 * 28)
        base_model = Qwen2VLForConditionalGeneration.from_pretrained(model_id, torch_dtype=torch.bfloat16,
                                                                     device_map="cuda")
        self.model = PeftModel.from_pretrained(base_model, "/model_v3/moj_model_qwen")

    @modal.method()
    def przetworz_zdjecie(self, image_bytes: bytes, filename: str):
        import json
        from PIL import Image

        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # ZMIENIONY PROMPT: Qwen decyduje, czy to paragon
        prompt = """Przeanalizuj to zdjęcie. 
        Jeśli na zdjęciu NIE MA paragonu, rachunku ani faktury, zwróć dokładnie ten JSON: {"status": "to_nie_jest_paragon"}
        Jeśli to JEST paragon, wyciągnij dane jako JSON. Oczyść nazwy (usuń wagi, marki, gramatury). Zwróć tylko czystą nazwę produktu."""

        messages = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": prompt}]}]
        text = self.processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = self.processor(text=[text], images=[img], padding=True, return_tensors="pt").to("cuda")

        generated_ids = self.model.generate(**inputs, max_new_tokens=1024)
        generated_ids_trimmed = [out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)]
        output_text = self.processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True)[0]

        try:
            cleaned = output_text.strip().removeprefix("```json").removesuffix("```").strip()
            dane_json = json.loads(cleaned)

            # Reakcja na odrzucenie zdjęcia
            if isinstance(dane_json, dict) and dane_json.get("status") == "to_nie_jest_paragon":
                return {"status": "error", "message": "AI odrzuciło zdjęcie: To nie jest paragon."}

            return {"status": "success", "dane": dane_json}
        except Exception as e:
            return {"status": "error", "message": "Błąd parsowania JSON z Qwena", "raw_output": output_text}


# ==========================================
# ⚡ SILNIK 2: PALIGEMMA
# ==========================================

@app.cls(image=image, gpu="T4",
         volumes={"/zapisane_paragony": wolumen_paragonow, "/model_paligemma": wolumen_paligemma},
         secrets=[modal.Secret.from_name("huggingface")])
class PaliGemmaModel:
    @modal.enter()
    def start_maszyny(self):
        import torch
        from transformers import PaliGemmaProcessor, PaliGemmaForConditionalGeneration
        from peft import PeftModel

        model_id = "google/paligemma-3b-pt-224"
        self.processor = PaliGemmaProcessor.from_pretrained(model_id)
        base_model = PaliGemmaForConditionalGeneration.from_pretrained(
            model_id, torch_dtype=torch.bfloat16, device_map="cuda", attn_implementation="eager"
        )
        self.model = PeftModel.from_pretrained(base_model, "/model_paligemma/moj_model_paligemma")
        self.model.eval()

    @modal.method()
    def przetworz_zdjecie(self, image_bytes: bytes, filename: str):
        import json
        import torch
        from PIL import Image

        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # Pamiętaj: PaliGemma wymaga oryginalnego promptu z treningu!
        inputs = self.processor(text="<image> extract json: ", images=img, return_tensors="pt").to("cuda")

        with torch.inference_mode():
            generated_ids = self.model.generate(**inputs, max_new_tokens=512)

        input_len = inputs["input_ids"].shape[1]
        generated_tokens = generated_ids[0][input_len:]
        output_text = self.processor.decode(generated_tokens, skip_special_tokens=True)

        try:
            dane_json = json.loads(output_text.strip())
            # Pythonowe sprawdzanie, czy to przypomina paragon (zabezpieczenie)
            if "kwota_calkowita" not in dane_json and "pozycje" not in dane_json:
                return {"status": "error", "message": "AI nie rozpoznało tu struktury paragonu."}

            return {"status": "success", "dane": dane_json}
        except Exception as e:
            return {"status": "error", "message": "PaliGemma odrzuciła zdjęcie (Brak JSON).", "raw_output": output_text}


# ==========================================
# 🌐 FASTAPI ENDPOINTY
# ==========================================

@app.function(image=image)
@modal.asgi_app()
def fastapi_endpoint():
    # Endpoint dla Qwena
    @web_app.post("/skanuj_qwen")
    async def skanuj_qwen(file: UploadFile = File(...)):
        image_bytes = await file.read()
        model_instance = QwenModel()
        return model_instance.przetworz_zdjecie.remote(image_bytes, file.filename)

    # Endpoint dla PaliGemmy
    @web_app.post("/skanuj_paligemma")
    async def skanuj_paligemma(file: UploadFile = File(...)):
        image_bytes = await file.read()
        model_instance = PaliGemmaModel()
        return model_instance.przetworz_zdjecie.remote(image_bytes, file.filename)

    return web_app