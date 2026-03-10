import tkinter as tk
from tkinter import messagebox
import json
import os
from PIL import Image, ImageTk

# ==========================================
# ⚙️ KONFIGURACJA
# ==========================================
PLIK_WEJSCIOWY = "dataset_niedokładny.jsonl"
PLIK_WYJSCIOWY = "dataset_finalny.jsonl"


class WeryfikatorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Księgowy AI - Weryfikator Datasetu")
        self.root.geometry("1400x900")

        self.dataset = []
        self.aktualny_indeks = 0
        self.oryginalny_obraz = None
        self.tk_obraz = None

        # --- ZMIENNE DO ZOOMA I PRZESUWANIA ---
        self.scale = 1.0  # Aktualne powiększenie
        self.base_scale = 1.0  # Skala początkowa dopasowania do okna
        self.cur_x = 0  # Przesunięcie X
        self.cur_y = 0  # Przesunięcie Y
        self.drag_data = {"x": 0, "y": 0}  # Dane do przeciągania myszką
        self.aktualny_obrot = 0

        self.wczytaj_dane()
        self.buduj_interfejs()
        self.zaladuj_paragon()

    def wczytaj_dane(self):
        przerobione_sciezki = set()
        if os.path.exists(PLIK_WYJSCIOWY):
            with open(PLIK_WYJSCIOWY, 'r', encoding='utf-8') as f:
                for line in f:
                    try:
                        przerobione_sciezki.add(json.loads(line)['image_path'])
                    except:
                        pass

        if not os.path.exists(PLIK_WEJSCIOWY):
            messagebox.showerror("Błąd", f"Nie znaleziono pliku wejściowego:\n{PLIK_WEJSCIOWY}")
            self.root.destroy()
            return

        with open(PLIK_WEJSCIOWY, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    dane = json.loads(line)
                    if dane['image_path'] not in przerobione_sciezki:
                        self.dataset.append(dane)
                except:
                    pass

        if not self.dataset:
            messagebox.showinfo("Koniec!", "Wszystkie paragony zostały już zweryfikowane!")
            self.root.destroy()

    def buduj_interfejs(self):
        # --- LEWY PANEL (PŁÓTNO DO ZOOMA) ---
        self.panel_lewy = tk.Frame(self.root, bg='black')
        self.panel_lewy.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # MAGIA: Zamieniliśmy tk.Label na tk.Canvas!
        self.canvas = tk.Canvas(self.panel_lewy, bg='gray30', highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # --- EVENTY MYSZY DLA CANVASU ---
        # Obsługa scrolla (Windows/macOS)
        self.canvas.bind("<MouseWheel>", self.obsluga_zooma)
        # Obsługa scrolla (Linux)
        self.canvas.bind("<Button-4>", self.obsluga_zooma)
        self.canvas.bind("<Button-5>", self.obsluga_zooma)

        # Przesuwanie (chwytanie paragonu)
        self.canvas.bind("<ButtonPress-1>", self.start_przesuwania)
        self.canvas.bind("<B1-Motion>", self.wykonaj_przesuwanie)
        # Dwuklik resetuje widok
        self.canvas.bind("<Double-Button-1>", self.reset_widoku)

        # Uaktualnienie rozmiaru canvasu (potrzebne do poprawnego dopasowania)
        self.canvas.bind("<Configure>", lambda e: self.pokaz_obraz(reset_view=True) if self.oryginalny_obraz else None)

        # --- PRAWY PANEL (FORMULARZ Human-Friendly) ---
        self.panel_prawy = tk.Frame(self.root, width=500, padx=20, pady=20)
        self.panel_prawy.pack(side=tk.RIGHT, fill=tk.Y)

        self.info_label = tk.Label(self.panel_prawy, text="", fg="blue", font=("Arial", 10, "bold"))
        self.info_label.pack(anchor="w", pady=(0, 10))

        # --- POLA GŁÓWNE ---
        ramka_naglowek = tk.Frame(self.panel_prawy)
        ramka_naglowek.pack(fill=tk.X)

        def dodaj_pole(parent, label, row):
            tk.Label(parent, text=label, font=("Arial", 11, "bold")).grid(row=row, column=0, sticky="w", pady=3)
            entry = tk.Entry(parent, font=("Arial", 12), width=35)
            entry.grid(row=row, column=1, pady=3, padx=10, sticky="ew")
            return entry

        self.e_sklep = dodaj_pole(ramka_naglowek, "Sklep:", 0)
        self.e_data = dodaj_pole(ramka_naglowek, "Data:", 1)
        self.e_suma = dodaj_pole(ramka_naglowek, "Suma (zł):", 2)
        ramka_naglowek.columnconfigure(1, weight=1)

        # --- LISTA PRODUKTÓW ---
        instrukcja_prod = tk.Label(self.panel_prawy,
                                   text="Produkty (Format: Cena | Nazwa)\nCtrl+D usuwa linię, Ctrl+L czyści",
                                   font=("Arial", 9), fg="gray", justify=tk.LEFT)
        instrukcja_prod.pack(anchor="w", pady=(15, 0))
        tk.Label(self.panel_prawy, text="Lista Pozycji:", font=("Arial", 11, "bold")).pack(anchor="w", pady=(0, 5))

        self.t_produkty = tk.Text(self.panel_prawy, font=("Consolas", 13), wrap=tk.WORD, height=18)
        self.t_produkty.pack(fill=tk.BOTH, expand=True)

        # --- PRZYCISKI I SKRÓTY GLOBALNE ---
        ramka_przyciski = tk.Frame(self.panel_prawy)
        ramka_przyciski.pack(pady=20, fill=tk.X)

        tk.Button(ramka_przyciski, text="Obróć 90° (R)", command=self.obroc_zdjecie, bg="lightblue",
                  font=("Arial", 11, "bold")).pack(side=tk.LEFT, padx=5, expand=True, fill=tk.X)
        tk.Button(ramka_przyciski, text="Reset Widoku (Double Click)",
                  command=lambda: self.pokaz_obraz(reset_view=True), bg="#eee", font=("Arial", 9)).pack(side=tk.LEFT,
                                                                                                        padx=5)
        tk.Button(ramka_przyciski, text="Zapisz i Dalej (Ctrl+Enter)", command=self.zapisz_i_dalej, bg="lightgreen",
                  font=("Arial", 11, "bold")).pack(side=tk.LEFT, padx=5, expand=True, fill=tk.X)

        # Skróty klawiszowe (Globalne dla roota)
        self.root.bind('<Control-Return>', lambda event: self.zapisz_i_dalej())
        self.root.bind('<Escape>', lambda event: self.pomin())

        # Skróty dla pola tekstowego
        self.t_produkty.bind('<Control-d>', self.usun_linie)
        self.t_produkty.bind('<Control-l>', self.wyczysc_produkty)

    # ==========================================
    # 🧠 LOGIKA OBRAZU I ZOOMA
    # ==========================================

    def obsluga_zooma(self, event):
        if not self.oryginalny_obraz: return

        # Kierunek zoomu (zależnie od systemu i przycisku)
        dzialanie = 0
        if event.num == 4 or event.delta > 0:
            dzialanie = 1  # Zoom IN
        elif event.num == 5 or event.delta < 0:
            dzialanie = -1  # Zoom OUT

        if dzialanie == 0: return

        # Ustalenie punktu stałego zoomu (pozycja myszy na canvasie)
        x_myszy = self.canvas.canvasx(event.x)
        y_myszy = self.canvas.canvasy(event.y)

        czynnik_zoomu = 1.2  # O ile powiększać/zmniejszać na jeden scroll
        stara_skala = self.scale

        # Obliczanie nowej skali
        if dzialanie > 0:
            self.scale *= czynnik_zoomu
        else:
            self.scale /= czynnik_zoomu

        # Blokada zooma (od base_scale do 8-krotności oryginału)
        self.scale = max(self.base_scale, min(self.scale, 8.0))

        if stara_skala == self.scale: return  # Nic się nie zmieniło

        # Korekta przesunięcia (żeby zoomować w punkt myszy)
        wspolczynnik = self.scale / stara_skala
        self.cur_x = x_myszy - wspolczynnik * (x_myszy - self.cur_x)
        self.cur_y = y_myszy - wspolczynnik * (y_myszy - self.cur_y)

        self.pokaz_obraz(reset_view=False)

    def start_przesuwania(self, event):
        self.drag_data["x"] = event.x
        self.drag_data["y"] = event.y

    def wykonaj_przesuwanie(self, event):
        if not self.oryginalny_obraz or self.scale == self.base_scale: return

        # Oblicz przesunięcie
        dx = event.x - self.drag_data["x"]
        dy = event.y - self.drag_data["y"]

        self.cur_x += dx
        self.cur_y += dy

        # Zapamiętaj nową pozycję myszy
        self.drag_data["x"] = event.x
        self.drag_data["y"] = event.y

        self.pokaz_obraz(reset_view=False)

    def reset_widoku(self, event=None):
        if self.oryginalny_obraz:
            self.pokaz_obraz(reset_view=True)

    def pokaz_obraz(self, reset_view=False):
        if not self.oryginalny_obraz: return

        # 1. Weź oryginał i obróć
        obraz_do_wyswietlenia = self.oryginalny_obraz.rotate(self.aktualny_obrot, expand=True)
        img_w, img_h = obraz_do_wyswietlenia.size

        # 2. Jeśli resetujemy widok, obliczamy base_scale (dopasowanie do okna)
        if reset_view:
            canv_w = self.canvas.winfo_width()
            canv_h = self.canvas.winfo_height()

            # Zabezpieczenie na start, gdy okno nie ma jeszcze rozmiaru
            if canv_w <= 1 or canv_h <= 1:
                canv_w = 700
                canv_h = 700

            # Skala, która zmieści cały obraz w oknie
            ratio_w = canv_w / img_w
            ratio_h = canv_h / img_h
            self.base_scale = min(ratio_w, ratio_h, 1.0)  # Nie powiększamy małych obrazów ponad 100% na starcie
            self.scale = self.base_scale

            # Środkujemy obraz na płótnie
            self.cur_x = (canv_w - (img_w * self.scale)) / 2
            self.cur_y = (canv_h - (img_h * self.scale)) / 2

        # 3. Skalujemy obrócony obraz
        nowa_szer = int(img_w * self.scale)
        nowa_wys = int(img_h * self.scale)

        if nowa_szer > 0 and nowa_wys > 0:
            obraz_skalowany = obraz_do_wyswietlenia.resize((nowa_szer, nowa_wys), Image.Resampling.LANCZOS)
            self.tk_obraz = ImageTk.PhotoImage(obraz_skalowany)

            # 4. Rysujemy na canvasie (najpierw czyścimy)
            self.canvas.delete("all")
            # Używamy anchor="nw" (north-west) i zarządzamy pozycją przez cur_x, cur_y
            self.canvas.create_image(self.cur_x, self.cur_y, image=self.tk_obraz, anchor="nw")
            # Ustawiamy scrollregion, żeby Tkinter wiedział, jak duży jest obraz
            self.canvas.config(scrollregion=self.canvas.bbox("all"))

    def obroc_zdjecie(self):
        if self.oryginalny_obraz:
            self.aktualny_obrot = (self.aktualny_obrot - 90) % 360
            self.pokaz_obraz(reset_view=True)  # Resetujemy zoom po obrocie, bo współrzędne wariują

    # ==========================================
    # 📝 DANE I FORMULARZ
    # ==========================================

    def wczytaj_i_parsuj_json(self, wiersz_text):
        try:
            return json.loads(wiersz_text)
        except:
            # Fallback dla błędnych danych
            return {}

    def zaladuj_paragon(self):
        if self.aktualny_indeks >= len(self.dataset):
            messagebox.showinfo("Koniec!", f"Dobra robota! Wynik zapisano w:\n{PLIK_WYJSCIOWY}")
            self.root.destroy()
            return

        dane_wiersz = self.dataset[self.aktualny_indeks]
        sciezka = dane_wiersz['image_path']

        self.info_label.config(
            text=f"📌 Paragon {self.aktualny_indeks + 1} z {len(self.dataset)}  |  Plik: {os.path.basename(sciezka)}")

        # Próba otwarcia zdjęcia
        try:
            self.oryginalny_obraz = Image.open(sciezka)
            # Pokazujemy obraz (pokaz_obraz zostanie wywołany przez Event <Configure> canvasu,
            # ale wywołujemy też tutaj w razie czego)
            self.root.after(100, lambda: self.pokaz_obraz(reset_view=True))
        except Exception as e:
            messagebox.showerror("Błąd", f"Nie można otworzyć zdjęcia:\n{e}\nŚcieżka: {sciezka}")
            self.pomin()
            return

        zawartosc = self.wczytaj_i_parsuj_json(dane_wiersz['text'])

        # Wypełnianie pól
        def wpisz_do_entry(entry, wartosc):
            entry.delete(0, tk.END)
            if wartosc is not None:
                entry.insert(0, str(wartosc))

        wpisz_do_entry(self.e_sklep, zawartosc.get('sklep', ''))
        # Obsługa dwóch formatów daty
        wpisz_do_entry(self.e_data, zawartosc.get('data_czas', zawartosc.get('data', '')))
        wpisz_do_entry(self.e_suma, zawartosc.get('kwota_calkowita', '0'))

        # Pozycje
        self.t_produkty.delete("1.0", tk.END)
        tekst_pozycje = ""
        for p in zawartosc.get('pozycje', []):
            tekst_pozycje += f"{p.get('cena', 0)} | {p.get('nazwa', '')}\n"
        self.t_produkty.insert(tk.END, tekst_pozycje.strip())

        # Fokus na pole sklepu na start
        self.e_sklep.focus_set()

    def zapisz_i_dalej(self):
        try:
            # Parsowanie sumy
            suma_str = self.e_suma.get().strip().replace(',', '.') or '0'
            try:
                suma_float = float(suma_str)
            except ValueError:
                raise ValueError(f"Błędny format kwoty całkowitej: '{suma_str}'")

            nowy_json = {
                "sklep": self.e_sklep.get().strip(),
                "data_czas": self.e_data.get().strip(),
                "kwota_calkowita": suma_float,
                "pozycje": []
            }

            linie = self.t_produkty.get("1.0", tk.END).strip().split('\n')
            for nr, linia in enumerate(linie, 1):
                if not linia.strip(): continue

                if '|' not in linia:
                    # Spróbujmy sparsować jeśli cena jest na końcu (np. "Mleko 3.50")
                    czesci = linia.strip().rsplit(' ', 1)
                    if len(czesci) == 2 and czesci[1].replace(',', '').replace('.', '').isdigit():
                        cena_s, nazwa_s = czesci[1], czesci[0]
                    else:
                        raise ValueError(
                            f"Błąd w linii {nr}: Brak znaku '|' lub formatu 'Cena | Nazwa'\nLinia: {linia}")
                else:
                    cena_str, nazwa_str = linia.split('|', 1)
                    cena_s, nazwa_s = cena_str.strip(), nazwa_str.strip()

                # Parsowanie ceny pozycji
                try:
                    p_cena = float(cena_s.replace(',', '.') or 0)
                except ValueError:
                    raise ValueError(f"Błąd ceny w linii {nr}: '{cena_s}' nie jest liczbą.")

                nowy_json["pozycje"].append({
                    "nazwa": nazwa_s,
                    "cena": p_cena
                })

            # Zapis maszynowy
            nowy_wiersz = {
                "image_path": self.dataset[self.aktualny_indeks]['image_path'],
                "text": json.dumps(nowy_json, ensure_ascii=False)
            }

            with open(PLIK_WYJSCIOWY, 'a', encoding='utf-8') as f:
                f.write(json.dumps(nowy_wiersz, ensure_ascii=False) + '\n')

            self.aktualny_indeks += 1
            self.zaladuj_paragon()

        except ValueError as e:
            messagebox.showerror("Błąd danych", str(e))
        except Exception as e:
            messagebox.showerror("Błąd krytyczny", f"Nieoczekiwany błąd:\n{e}")

    def pomin(self):
        self.aktualny_indeks += 1
        self.zaladuj_paragon()

    # Pomocnicze do tekstu
    def usun_linie(self, event):
        self.t_produkty.delete("insert linestart", "insert lineend + 1 chars")
        return "break"  # Blokuje domyślne działanie

    def wyczysc_produkty(self, event):
        self.t_produkty.delete("1.0", tk.END)
        return "break"


if __name__ == "__main__":
    # Sprawdzanie wymagań
    try:
        from PIL import Image, ImageTk
    except ImportError:
        import sys

        print("❌ BŁĄD: Brakuje biblioteki Pillow.")
        print("Wpisz w terminal: pip install Pillow")
        sys.exit(1)

    root = tk.Tk()
    app = WeryfikatorApp(root)

    # Naprawa dla systemów z ekranami HiDPI
    try:
        from ctypes import windll

        windll.shcore.SetProcessDpiAwareness(1)
    except:
        pass

    root.mainloop()