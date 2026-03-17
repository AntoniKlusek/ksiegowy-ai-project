import os
import torch
from datasets import load_dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import (
    Qwen2VLForConditionalGeneration,
    AutoProcessor,
    TrainingArguments,
    Trainer,
    BitsAndBytesConfig
)
from qwen_vl_utils import process_vision_info

# ==========================================
# KONFIGURACJA
# ==========================================
DATASET_PATH = "dataset_ocr_finalny.jsonl"
OUTPUT_DIR = "./qwen_ocr_lora"
OPT_MAX_PIXELS = 1024 * 1024

SYSTEM_PROMPT = """Jesteś precyzyjnym systemem OCR. Twoim zadaniem jest odczytanie paragonu ze zdjęcia.
ZACHOWAJ oryginalną pisownię, wszystkie skróty, dziwne znaki, wielkość liter i gramatury dokładnie tak, jak widać na zdjęciu. 
ABSOLUTNIE NIE poprawiaj nazw produktów i nie usuwaj żadnych słów.
Zwróć wynik TYLKO jako czysty format JSON."""


def format_data(example):
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image", "image": example["image_path"]},
                {"type": "text", "text": SYSTEM_PROMPT}
            ]
        },
        {
            "role": "assistant",
            "content": [{"type": "text", "text": example["text"]}]
        }
    ]
    return {"messages": messages}


# ==========================================
# CUSTOM DATA COLLATOR Z MASKOWANIEM PROMPTU
# ==========================================
class Qwen2VLDataCollator:
    def __init__(self, processor):
        self.processor = processor

    def __call__(self, features):
        texts = []
        image_inputs_list = []

        for feature in features:
            clean_messages = []
            for msg in feature["messages"]:
                clean_content = []
                for item in msg["content"]:
                    clean_item = {k: v for k, v in item.items() if v is not None}
                    clean_content.append(clean_item)
                clean_messages.append({"role": msg["role"], "content": clean_content})

            text = self.processor.apply_chat_template(clean_messages, tokenize=False, add_generation_prompt=False)
            texts.append(text)

            image_inputs, _ = process_vision_info(clean_messages)
            if image_inputs is not None:
                image_inputs_list.extend(image_inputs)

        batch = self.processor(
            text=texts,
            images=image_inputs_list if len(image_inputs_list) > 0 else None,
            padding=True,
            return_tensors="pt"
        )

        labels = batch["input_ids"].clone()
        # 1. Maskowanie paddingu
        labels[labels == self.processor.tokenizer.pad_token_id] = -100

        # 2. PANCERNE MASKOWANIE PROMPTU (Magia!)
        # Token 151644 to <|im_start|>, a 77091 to słowo 'assistant' w Qwen2
        for i in range(labels.shape[0]):
            seq = labels[i].tolist()
            for j in range(len(seq) - 1):
                if seq[j] == 151644 and seq[j + 1] == 77091:
                    # Maskujemy wszystko przed odpowiedzią asystenta
                    labels[i, :j + 3] = -100
                    break

        batch["labels"] = labels
        return batch


def main():
    print("📦 Wczytywanie datasetu...")
    dataset = load_dataset("json", data_files=DATASET_PATH, split="train")
    dataset = dataset.map(format_data, remove_columns=["image_path", "text"])

    print("🧠 Konfiguracja modelu...")
    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16
    )

    model = Qwen2VLForConditionalGeneration.from_pretrained(
        "Qwen/Qwen2-VL-2B-Instruct",
        quantization_config=bnb_config,
        device_map="auto"
    )
    model = prepare_model_for_kbit_training(model)

    processor = AutoProcessor.from_pretrained(
        "Qwen/Qwen2-VL-2B-Instruct",
        min_pixels=256 * 256,
        max_pixels=OPT_MAX_PIXELS
    )

    print("🛠️ Konfiguracja LoRA...")
    peft_config = LoraConfig(
        r=16,
        lora_alpha=32,
        lora_dropout=0.05,
        bias="none",
        target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
        task_type="CAUSAL_LM"
    )
    model = get_peft_model(model, peft_config)
    model.print_trainable_parameters()

    training_args = TrainingArguments(
        output_dir=OUTPUT_DIR,
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4,
        optim="paged_adamw_32bit",
        save_steps=20,
        logging_steps=5,
        learning_rate=2e-4,
        weight_decay=0.001,
        fp16=False,
        bf16=True,
        max_grad_norm=0.3,
        max_steps=150,
        lr_scheduler_type="cosine",
        report_to="none",
        remove_unused_columns=False,

        # 🔥 ZBAWIENNE PARAMETRY DLA SZYBKOŚCI I PAMIĘCI 🔥
        gradient_checkpointing=True,  # Oszczędza gigabajty VRAM-u!
        gradient_checkpointing_kwargs={"use_reentrant": False},  # Wyłącza denerwujące ostrzeżenie z logów
        dataloader_num_workers=2,  # Ładuje kolejne zdjęcia w tle
    )

    print("🚀 Start w pełni poprawionego treningu...")
    collator = Qwen2VLDataCollator(processor)

    trainer = Trainer(
        model=model,
        train_dataset=dataset,
        data_collator=collator,
        args=training_args,
    )

    trainer.train()

    print(f"💾 Zapisywanie wytrenowanych wag do {OUTPUT_DIR}...")
    trainer.model.save_pretrained(OUTPUT_DIR)
    processor.save_pretrained(OUTPUT_DIR)
    print("✅ Trening zakończony sukcesem!")


if __name__ == "__main__":
    main()