import cv2
import os
import json

# ==========================================
# ⚙️ KONFIGURACJA
# ==========================================
# Zmień na nazwę swojego starego datasetu:
PLIK_WEJSCIOWY_JSONL = "dataset.jsonl"
PLIK_WYJSCIOWY_JSONL = "dataset_niedokładny.jsonl"
FOLDER_NOWYCH_ZDJEC = "paragony_uciete"

# Tworzymy folder na ucięte wersje, jeśli nie istnieje
os.makedirs(FOLDER_NOWYCH_ZDJEC, exist_ok=True)

print("=== ✂️ NARZĘDZIE DO CIĘCIA PARAGONÓW ===")
print("Instrukcja:")
print("1. Zaznacz myszką prostokąt wokół paragonu.")
print("2. Wciśnij ENTER lub SPACJĘ, aby uciąć i przejść dalej.")
print("3. Wciśnij 'c', aby pominąć zdjęcie (jeśli paragon jest nieczytelny).")
print("=========================================\n")

# Tryb 'a' (append) pozwala przerwać pracę i wrócić do niej później bez utraty postępu!
with open(PLIK_WEJSCIOWY_JSONL, 'r', encoding='utf-8') as f_in, \
        open(PLIK_WYJSCIOWY_JSONL, 'a', encoding='utf-8') as f_out:
    for linia in f_in:
        dane = json.loads(linia)
        sciezka_zdjecia = dane['image_path']

        if not os.path.exists(sciezka_zdjecia):
            print(f"❌ Brak pliku na dysku: {sciezka_zdjecia}")
            continue

        # Wczytanie oryginalnego zdjęcia
        img = cv2.imread(sciezka_zdjecia)

        # Magia nr 1: Okno dostosowujące się do ekranu (oryginały z telefonu są za duże)
        cv2.namedWindow("Wytnij paragon", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("Wytnij paragon", 800, 900)

        # Magia nr 2: Uruchamiamy natywny mechanizm zaznaczania ROI (Region of Interest)
        roi = cv2.selectROI("Wytnij paragon", img, fromCenter=False, showCrosshair=True)

        x, y, w, h = roi
        # Jeśli ktoś nie zaznaczył niczego (wciśnięto 'c' lub 'Esc')
        if w == 0 or h == 0:
            print(f"⏭️ Pominięto: {sciezka_zdjecia}")
            continue

        # Wycinamy piksele!
        uciety_obraz = img[int(y):int(y + h), int(x):int(x + w)]

        # Tworzymy nową ścieżkę do zapisu
        nazwa_pliku = os.path.basename(sciezka_zdjecia)
        nowa_sciezka = os.path.join(FOLDER_NOWYCH_ZDJEC, f"uciete_{nazwa_pliku}")

        # Zapisujemy idealnie ucięty paragon
        cv2.imwrite(nowa_sciezka, uciety_obraz)

        # Tworzymy nową linijkę do pliku JSONL
        nowe_dane = {
            "image_path": nowa_sciezka,
            "text": dane['text']  # Kopiujemy Twój stary, dobry tekst JSON!
        }
        f_out.write(json.dumps(nowe_dane, ensure_ascii=False) + '\n')

        print(f"✅ Ucięto i zapisano: {nowa_sciezka}")

cv2.destroyAllWindows()
print("\n🎉 Zakończono czyszczenie datasetu! Twój nowy plik to:", PLIK_WYJSCIOWY_JSONL)