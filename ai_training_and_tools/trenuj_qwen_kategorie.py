import torch
import json
from datasets import load_dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import (
    Qwen2VLForConditionalGeneration,
    AutoProcessor,
    TrainingArguments,
    Trainer,
    BitsAndBytesConfig
)

# ==========================================
# KONFIGURACJA
# ==========================================
DATASET_PATH = "dataset_kategoryzacja_finalny.jsonl"
OUTPUT_DIR = "./qwen_kategorie_lora"

SYSTEM_PROMPT = """Twoim zadaniem jest ujednolicenie nazwy produktu z paragonu. 
Zwróć TYLKO czystą, znormalizowaną nazwę lub kategorię, bez żadnych dodatkowych słów, znaków zapytania czy wyjaśnień."""


def format_data(example):
    """Pakuje wejście i wyjście z Twojego Złotego Standardu w rygorystyczny dialog"""
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f'Wejście: "{example["wejscie"]}" -> Wyjście:'},
        {"role": "assistant", "content": example["wyjscie"]}
    ]
    return {"messages": messages}


# ==========================================
# LEKKI COLLATOR TYLKO DLA TEKSTU Z MASKOWANIEM
# ==========================================
class TextOnlyDataCollator:
    def __init__(self, processor):
        self.processor = processor

    def __call__(self, features):
        texts = []
        for feature in features:
            # Tu już nie ma czyszczenia "None", bo nie dotykamy zdjęć
            text = self.processor.apply_chat_template(feature["messages"], tokenize=False, add_generation_prompt=False)
            texts.append(text)

        # Procesor pakuje tylko tekst, bez klucza images
        batch = self.processor(
            text=texts,
            padding=True,
            return_tensors="pt"
        )

        labels = batch["input_ids"].clone()
        # 1. Maskowanie paddingu
        labels[labels == self.processor.tokenizer.pad_token_id] = -100

        # 2. Nasza tarcza na prompt (-100)
        # Token 151644 to <|im_start|>, a 77091 to 'assistant'
        for i in range(labels.shape[0]):
            seq = labels[i].tolist()
            for j in range(len(seq) - 1):
                if seq[j] == 151644 and seq[j + 1] == 77091:
                    labels[i, :j + 3] = -100
                    break

        batch["labels"] = labels
        return batch


def main():
    print("📦 Wczytywanie tekstowego datasetu...")
    dataset = load_dataset("json", data_files=DATASET_PATH, split="train")
    dataset = dataset.map(format_data, remove_columns=["wejscie", "wyjscie"])

    print("🧠 Konfiguracja modelu (Tym razem ładujemy go bez obrazów!)...")
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
    processor = AutoProcessor.from_pretrained("Qwen/Qwen2-VL-2B-Instruct")

    print("🛠️ Konfiguracja drugiego adaptera LoRA...")
    peft_config = LoraConfig(
        r=16,
        lora_alpha=32,
        lora_dropout=0.05,
        bias="none",
        target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
        task_type="CAUSAL_LM"
    )
    model = get_peft_model(model, peft_config)

    # 🚀 Przyspieszamy! Batch size 4, bo tekst mało waży
    training_args = TrainingArguments(
        output_dir=OUTPUT_DIR,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=1,
        optim="paged_adamw_32bit",
        save_steps=50,
        logging_steps=5,
        learning_rate=3e-4,  # Tekst można uczyć odrobinę wyższym learning ratem
        weight_decay=0.001,
        fp16=False,
        bf16=True,
        max_steps=150,
        lr_scheduler_type="cosine",
        report_to="none",
        remove_unused_columns=False,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False}
    )

    print("🚀 Start błyskawicznego treningu...")
    collator = TextOnlyDataCollator(processor)

    trainer = Trainer(
        model=model,
        train_dataset=dataset,
        data_collator=collator,
        args=training_args,
    )

    trainer.train()

    print(f"💾 Zapisywanie gotowego adaptera do {OUTPUT_DIR}...")
    trainer.model.save_pretrained(OUTPUT_DIR)
    processor.save_pretrained(OUTPUT_DIR)
    print("✅ Gotowe! Mamy drugi element układanki.")


if __name__ == "__main__":
    main()