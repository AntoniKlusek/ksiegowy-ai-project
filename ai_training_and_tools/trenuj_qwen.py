import os
import torch
from PIL import Image
from datasets import load_dataset
from transformers import AutoProcessor, Qwen2VLForConditionalGeneration, TrainingArguments, Trainer
from peft import LoraConfig, get_peft_model

print("=== 🚀 Trening Qwen2-VL ===")

# ==========================================
# 1. KONFIGURACJA
# ==========================================
MODEL_ID = "Qwen/Qwen2-VL-2B-Instruct"
DATASET_PATH = "dataset.jsonl"
OUTPUT_DIR = "./moj_model_qwen"

print("[*] Ładowanie procesora...")
processor = AutoProcessor.from_pretrained(
    MODEL_ID,
    min_pixels=256 * 28 * 28,
    max_pixels=1024 * 28 * 28
)

print("[*] Ładowanie datasetu...")
dataset = load_dataset("json", data_files=DATASET_PATH, split="train")

print("[*] Ładowanie modelu bazowego (bfloat16)...")
model = Qwen2VLForConditionalGeneration.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.bfloat16,
    device_map="cuda"
)

# ==========================================
# 2. KONFIGURACJA LORA
# ==========================================

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    bias="none",
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    task_type="CAUSAL_LM"
)
model = get_peft_model(model, lora_config)


# ==========================================
# 3. WŁASNY PODAJNIK DANYCH (Data Collator z Maskowaniem)
# ==========================================

class QwenDataCollator:
    def __init__(self, processor):
        self.processor = processor

    def __call__(self, examples):
        texts = []
        images = []

        for example in examples:
            image = Image.open(example["image_path"]).convert("RGB")
            images.append(image)

            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "image"},
                        {"type": "text",
                         "text": "Wyciągnij dane z paragonu i sformatuj je jako surowy kod JSON. Kluczowa zasada: Oczyść nazwy produktów. Usuń nazwy własne i marki, usuń gramatury, wagi i pojemności oraz zbędne opisy. Zwróć tylko czystą, ogólną nazwę produktu."}
                    ]
                },
                {
                    "role": "assistant",
                    "content": [{"type": "text", "text": example["text"]}]
                }
            ]
            text = self.processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
            texts.append(text)

        batch = self.processor(
            text=texts,
            images=images,
            padding=True,
            return_tensors="pt"
        )

        labels = batch["input_ids"].clone()
        labels[labels == self.processor.tokenizer.pad_token_id] = -100

        # 🔴 KRYTYCZNA MAGIA: Maskowanie promptu i obrazka 🔴
        # Chcemy, by model uczył się TYLKO generowania JSON-a.
        # W Qwen token 151644 to '<|im_start|>'. Ostatni w sekwencji oznacza asystenta.
        for i in range(labels.shape[0]):
            im_starts = (labels[i] == 151644).nonzero(as_tuple=True)[0]
            if len(im_starts) > 0:
                assistant_idx = im_starts[-1].item()
                # Maskujemy wszystko do znacznika asystenta (+3 to margines na słowo 'assistant' i '\n')
                # Model będzie miał liczoną stratę TYLKO od momentu, w którym zaczyna pisać znak '{'
                labels[i, :assistant_idx + 3] = -100

        batch["labels"] = labels
        return batch


# ==========================================
# 4. PARAMETRY TRENINGU (Krótki, precyzyjny strzał)
# ==========================================

training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,
    optim="adamw_torch",
    save_steps=20,     # Zapisujemy co 20 kroków
    logging_steps=5,
    learning_rate=2e-4,
    bf16=True,
    fp16=False,
    max_grad_norm=0.3,
    warmup_steps=5,
    lr_scheduler_type="constant",
    max_steps=28,
    report_to="none",
    remove_unused_columns=False,
)

# ==========================================
# 5. START TRENINGU
# ==========================================
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
    data_collator=QwenDataCollator(processor)
)

print(f"[*] Rozpoczynamy poprawny trening!")
trainer.train()

print("[*] Zapisywanie modelu Księgowy AI")
trainer.save_model(OUTPUT_DIR)
processor.save_pretrained(OUTPUT_DIR)
print(f"=== ✨ Gotowe! Model Qwen zapisany w: {OUTPUT_DIR} ===")