import os
import torch
from PIL import Image
from datasets import load_dataset
from transformers import PaliGemmaForConditionalGeneration, PaliGemmaProcessor, TrainingArguments, Trainer
from peft import LoraConfig, get_peft_model, TaskType

print("=== 🚀 Trening PaliGemma (Księgowy AI) ===")

# ==========================================
# 1. KONFIGURACJA
# ==========================================

MODEL_ID = "google/paligemma-3b-pt-224"
DATASET_PATH = "dataset.jsonl"
OUTPUT_DIR = "./moj_model_paligemma"

print("[*] Ładowanie procesora...")
processor = PaliGemmaProcessor.from_pretrained(MODEL_ID)

print("[*] Ładowanie datasetu...")
dataset = load_dataset("json", data_files=DATASET_PATH, split="train")

print("[*] Ładowanie modelu bazowego (bfloat16)...")
model = PaliGemmaForConditionalGeneration.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.bfloat16,
    device_map="cuda",
    attn_implementation="eager"
)

# ==========================================
# 2. KONFIGURACJA LORA
# ==========================================

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    bias="none",
    # Targetujemy warstwy wizyjne (SigLIP) i tekstowe (Gemma)
    target_modules=["q_proj", "v_proj", "k_proj", "out_proj", "gate_proj", "up_proj", "down_proj"],
    task_type=TaskType.CAUSAL_LM
)
model = get_peft_model(model, lora_config)

# ==========================================
# 3. WŁASNY PODAJNIK DANYCH (Z Maskowaniem Promptu)
# ==========================================

class PaliGemmaDataCollator:
    def __init__(self, processor):
        self.processor = processor
        self.image_size = 224

    def __call__(self, examples):
        from PIL import Image
        texts = []
        images = []
        prompts = []

        for example in examples:
            # 1. Obrazek
            image = Image.open(example["image_path"]).convert("RGB").resize((self.image_size, self.image_size))
            images.append(image)

            # 2. Cel (JSON)
            target = example["text"]
            texts.append(target)

            # 3. Prompt
            prompts.append("<image> extract json: ")

        # Tokenizacja: Zwracamy czyste tensory
        inputs = self.processor(
            text=prompts,
            images=images,
            return_tensors="pt",
            padding="longest",
            suffix=texts
        )

        labels = inputs["labels"].clone()
        inputs["labels"] = labels

        return inputs

# ==========================================
# 4. PARAMETRY TRENINGU
# ==========================================

training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=4,
    optim="adamw_torch",
    save_steps=50,
    logging_steps=10,
    learning_rate=2e-4,
    bf16=True,
    max_grad_norm=1.0,
    warmup_steps=10,
    lr_scheduler_type="constant",
    max_steps=70,
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
    data_collator=PaliGemmaDataCollator(processor)
)

print(f"[*] Rozpoczynamy trening PaliGemma!")
trainer.train()

print("[*] Zapisywanie modelu PaliGemma...")
trainer.save_model(OUTPUT_DIR)
processor.save_pretrained(OUTPUT_DIR)
print(f"=== ✨ Gotowe! Model PaliGemma zapisany w: {OUTPUT_DIR} ===")