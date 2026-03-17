import json

PLIK_WEJSCIOWY = "dataset_ocr_finalny.jsonl"
PLIK_WYJSCIOWY = "dataset_kategoryzacja_niedokladny.jsonl"


def generuj_baze_kategorii():
    unikalne_nazwy = set()

    print("🔍 Skanowanie Złotego Standardu...")
    with open(PLIK_WEJSCIOWY, 'r', encoding='utf-8') as f:
        for linia in f:
            if not linia.strip():
                continue

            dane = json.loads(linia)
            # W naszym datasecie 'text' to stringified JSON
            paragon_dane = json.loads(dane['text'])

            # Wyciągamy nazwy z sekcji 'pozycje'
            if 'pozycje' in paragon_dane:
                for pozycja in paragon_dane['pozycje']:
                    if 'nazwa' in pozycja:
                        unikalne_nazwy.add(pozycja['nazwa'].strip())

    print("💾 Zapisywanie do nowego formatu...")
    with open(PLIK_WYJSCIOWY, 'w', encoding='utf-8') as f:
        # Sortujemy alfabetycznie, żeby był porządek
        for nazwa in sorted(unikalne_nazwy):
            nowy_wiersz = {
                "wejscie": nazwa,
                "wyjscie": ""
            }
            f.write(json.dumps(nowy_wiersz, ensure_ascii=False) + "\n")

    print(f"✅ Gotowe! Wyciągnięto {len(unikalne_nazwy)} unikalnych produktów.")
    print(f"📂 Zapisano w: {PLIK_WYJSCIOWY}")


if __name__ == "__main__":
    generuj_baze_kategorii()