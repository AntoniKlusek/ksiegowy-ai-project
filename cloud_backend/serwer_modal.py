import modal
from fastapi import FastAPI, UploadFile, File
import io
import json
import re


# ==========================================
# 1. ŚRODOWISKO I POBIERANIE BAZY
# ==========================================
def download_models():
    import torch
    from transformers import AutoProcessor, Qwen2VLForConditionalGeneration

    print("[*] Pobieranie bazowego Qwen2-VL...")
    qwen_id = "Qwen/Qwen2-VL-2B-Instruct"
    AutoProcessor.from_pretrained(qwen_id)
    Qwen2VLForConditionalGeneration.from_pretrained(qwen_id, torch_dtype=torch.bfloat16)


image = (
    modal.Image.debian_slim()
    .pip_install(
        "fastapi[standard]", "torch", "torchvision", "transformers>=4.46.0",
        "pillow", "python-multipart", "peft", "qwen-vl-utils", "accelerate"
    )
    .run_function(download_models)
)

# ==========================================
# 2. DYSKI (VOLUMES)
# ==========================================
wolumen_paragonow = modal.Volume.from_name("archiwum-paragonow", create_if_missing=True)
# Tworzymy jeden dysk, na który wrzucisz oba foldery z wagami LoRA
wolumen_modele = modal.Volume.from_name("modele-lora-wolumen", create_if_missing=True)

app = modal.App("ksiegowy-ai-v5-multi-lora")
web_app = FastAPI()


def wyciagnij_json(tekst):
    """Pomocnicza pralka do wyciągania JSON-a z odpowiedzi LLM"""
    match = re.search(r'\{.*\}', tekst, re.DOTALL)
    if match:
        return match.group(0)
    return tekst


# ==========================================
# 🧠 SILNIK: QWEN 2 VL (DUAL-LORA)
# ==========================================
@app.cls(image=image, gpu="A10G", volumes={"/zapisane_paragony": wolumen_paragonow, "/modele_lora": wolumen_modele})
class MultiLoraOCR:
    @modal.enter()
    def start_maszyny(self):
        import torch
        from transformers import AutoProcessor, Qwen2VLForConditionalGeneration
        from peft import PeftModel

        print("🔥 Ładowanie bazowego modelu Qwen...")
        model_id = "Qwen/Qwen2-VL-2B-Instruct"
        self.processor = AutoProcessor.from_pretrained(model_id)

        base_model = Qwen2VLForConditionalGeneration.from_pretrained(
            model_id,
            torch_dtype=torch.bfloat16,
            device_map="cuda"
        )

        # ⚠️ WAŻNE: Upewnij się, że wgrałeś te foldery na wolumen "modele-lora-wolumen" w Modalu!
        print("🧩 Wpinanie modułu OCR (LoRA 1)...")
        self.model = PeftModel.from_pretrained(base_model, "/modele_lora/qwen_ocr_lora_v2", adapter_name="ocr")

        print("🧩 Wpinanie modułu Kategoryzacji (LoRA 2)...")
        self.model.load_adapter("/modele_lora/qwen_kategorie_lora", adapter_name="kategorie")

        # Nasze żelazne prompty
        self.PROMPT_OCR = """Jesteś precyzyjnym systemem OCR. Twoim zadaniem jest odczytanie paragonu ze zdjęcia.
ZACHOWAJ oryginalną pisownię, wszystkie skróty, dziwne znaki, wielkość liter i gramatury dokładnie tak, jak widać na zdjęciu. 
ABSOLUTNIE NIE poprawiaj nazw produktów i nie usuwaj żadnych słów.
Zwróć wynik TYLKO jako czysty format JSON."""

        self.PROMPT_KAT = """Twoim zadaniem jest ujednolicenie nazwy produktu z paragonu. 
Zwróć TYLKO czystą, znormalizowaną nazwę lub kategorię, bez żadnych dodatkowych słów, znaków zapytania czy wyjaśnień."""

    @modal.method()
    def przetworz_zdjecie(self, image_bytes: bytes, filename: str):
        import torch
        from PIL import Image
        from qwen_vl_utils import process_vision_info
        import io
        import os
        import time

        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # ---------------------------------------------------------
        # ZAPIS ZDJĘCIA NA CHMUROWY DYSK
        # ---------------------------------------------------------
        # Generujemy unikalną nazwę (znacznik czasu + nazwa), żeby pliki się nie nadpisywały
        bezpieczna_nazwa = f"{int(time.time())}_{filename}"
        sciezka_docelowa = os.path.join("/zapisane_paragony", bezpieczna_nazwa)

        # Zapisujemy plik fizycznie na wolumenie
        with open(sciezka_docelowa, "wb") as f:
            f.write(image_bytes)

        # WAŻNE W CHMURZE: Jawnie zapisujemy zmiany na dysku Modala
        wolumen_paragonow.commit()
        print(f"💾 Zapisano kopię w chmurze: {bezpieczna_nazwa}")

        # ---------------------------------------------------------
        # ETAP 1: ODCZYT ZDJĘCIA (OCR)
        # ---------------------------------------------------------
        self.model.set_adapter("ocr")

        messages_ocr = [
            {"role": "user", "content": [
                {"type": "image", "image": img},
                {"type": "text", "text": self.PROMPT_OCR}
            ]}
        ]

        text_ocr = self.processor.apply_chat_template(messages_ocr, tokenize=False, add_generation_prompt=True)
        image_inputs, video_inputs = process_vision_info(messages_ocr)

        inputs_ocr = self.processor(
            text=[text_ocr], images=image_inputs, videos=video_inputs, padding=True, return_tensors="pt",
            max_pixels=1024*1024
        ).to("cuda")

        with torch.inference_mode():
            generated_ids = self.model.generate(**inputs_ocr, max_new_tokens=512)

        generated_ids_trimmed = [out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs_ocr.input_ids, generated_ids)]
        output_ocr = self.processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True)[0]

        czysty_json = wyciagnij_json(output_ocr)

        try:
            dane_paragonu = json.loads(czysty_json)
        except json.JSONDecodeError:
            return {"status": "error", "message": "Błąd parsowania JSON z OCR", "raw_output": output_ocr}

        # ---------------------------------------------------------
        # ETAP 2: NORMALIZACJA TEKSTU I NADPISYWANIE
        # ---------------------------------------------------------
        self.model.set_adapter("kategorie")

        if "pozycje" in dane_paragonu:
            for pozycja in dane_paragonu["pozycje"]:
                if "nazwa" in pozycja:
                    surowa_nazwa = pozycja["nazwa"]

                    messages_kat = [
                        {"role": "system", "content": self.PROMPT_KAT},
                        {"role": "user", "content": f'Wejście: "{surowa_nazwa}" -> Wyjście:'}
                    ]
                    text_kat = self.processor.apply_chat_template(messages_kat, tokenize=False,
                                                                  add_generation_prompt=True)
                    inputs_kat = self.processor(text=[text_kat], padding=True, return_tensors="pt").to("cuda")

                    with torch.inference_mode():
                        gen_kat_ids = self.model.generate(**inputs_kat, max_new_tokens=20, temperature=0.1)

                    gen_kat_trimmed = [out_ids[len(in_ids):] for in_ids, out_ids in
                                       zip(inputs_kat.input_ids, gen_kat_ids)]
                    czysta_nazwa = self.processor.batch_decode(gen_kat_trimmed, skip_special_tokens=True)[0].strip()
                    czysta_nazwa = czysta_nazwa.replace('"', '').strip()

                    # Nadpisanie
                    pozycja["nazwa"] = czysta_nazwa

        return {"status": "success", "dane": dane_paragonu}




# ==========================================
# 🌐 FASTAPI ENDPOINT
# ==========================================
@app.function(image=image)
@modal.asgi_app()
def fastapi_endpoint():
    @web_app.post("/skanuj")
    async def skanuj_paragon(file: UploadFile = File(...)):
        image_bytes = await file.read()
        model_instance = MultiLoraOCR()

        # ZMIANA: Używamy .aio() dla poprawnego działania asynchronicznego!
        return await model_instance.przetworz_zdjecie.remote.aio(image_bytes, file.filename)

    return web_app