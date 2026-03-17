# 🧾 Księgowy AI - Skaner i Analizator Paragonów

> ⚠️ **Projekt PoC (Proof of Concept)**
> Aplikacja demonstracyjna służąca do testowania możliwości małych modeli wizyjno-językowych (VLM) w zadaniu wyciągania ustrukturyzowanych danych z polskich paragonów.

Projekt składa się z aplikacji mobilnej oraz chmurowego backendu (Serverless GPU). Celem systemu jest odczytanie zdjęcia paragonu, odfiltrowanie zbędnych informacji (np. gramatury, marki produktów) i zwrócenie czystego pliku JSON z listą zakupów, datą i kwotą.

---

## 📸 Podgląd

<div align="center">
  <img src="screenshots/1.jpg" width="220" alt="Ekran Główny">
  <img src="screenshots/2.jpg" width="220" alt="Ekran paragonów">
  <img src="screenshots/3.jpg" width="220" alt="Ekran produktów">
  <img src="screenshots/4.jpg" width="220" alt="Raporty">
  <img src="screenshots/5.jpg" width="220" alt="Ekran pojedynczego paragonu">
</div>

---

## 🚀 Główne cechy projektu

- **Architektura Multi-LoRA ("Czarna skrzynka"):** System wykorzystuje potężny model bazowy **Qwen2-VL**, do którego w locie wpinane są dwa niezależne adaptery (LoRA). Pierwszy odpowiada za surowy OCR i strukturę paragonu, drugi za semantyczne czyszczenie i ujednolicanie nazw produktów. Całość dzieje się w tle.
- **Własny Dataset i Narzędzia:** Stworzenie dedykowanego programu okienkowego (Python/Tkinter/OpenCV) do szybkiego oznaczania, docinania i formatowania danych treningowych z paragonów.
- **Inteligentne Skanowanie i Kolejkowanie:** Aplikacja mobilna automatycznie wykrywa krawędzie dokumentu przy skanowaniu z aparatu lub pozwala na masowe wysyłanie całych paczek zdjęć prosto z galerii urządzenia.
- **Architektura Serverless z 24GB VRAM:** Backend hostowany w chmurze Modal na maszynach z kartami **NVIDIA A10G**. Środowisko jest usypiane po zakończeniu pracy (zero kosztów w trybie idle), a maszyna "wstaje" automatycznie przy nowym zapytaniu z aplikacji.

---

## 🛠️ Stack Technologiczny

- **Aplikacja Mobilna:** Flutter, Dart, SQLite (do lokalnego zapisu historii i asynchronicznego linkowania danych).
- **Backend i Chmura:** Python, FastAPI, platforma Modal.
- **Machine Learning:** PyTorch, Transformers (Hugging Face), PEFT (LoRA), Accelerate.
- **Narzędzia lokalne (Data Prep):** Tkinter, OpenCV, Pillow.

---

## 📂 Struktura Repozytorium

```text
Ksiegowy_AI_Project/
├── mobile_app/                 # Kod źródłowy aplikacji (Flutter)
├── cloud_backend/              # API i wdrożenie na chmurę Modal (Python)
│   ├── serwer_modal.py         # Zunifikowany endpoint Multi-LoRA
│   └── requirements.txt
└── ai_training_and_tools/      # Narzędzia do budowy datasetu i skrypty uczące
    ├── trenuj_ocr_qwen.py      # Skrypt trenujący pierwszy adapter (struktura)
    ├── trenuj_kategorie.py     # Skrypt trenujący drugi adapter (czyszczenie nazw)
    ├── weryfikator_json.py     # Autorski program GUI do weryfikacji datasetu
    └── examples/               # Przykładowe dane treningowe
        ├── sample_dataset_ocr.jsonl
        └── sample_dataset_kategoryzacja.jsonl
```
