import tkinter as tk
from tkinter import messagebox
import json
import os

PLIK_WEJSCIOWY = "dataset_kategoryzacja_niedokladny.jsonl"
PLIK_WYJSCIOWY = "dataset_kategoryzacja_finalny.jsonl"


class WeryfikatorKategorii:
    def __init__(self, root):
        self.root = root
        self.root.title("Weryfikator Kategorii i Nazw (Multi-LoRA)")
        self.root.geometry("700x350")
        self.root.configure(padx=20, pady=20)

        self.dane = []
        self.obecny_indeks = 0

        self.wczytaj_dane()
        self.zbuduj_ui()

        if self.dane:
            self.pokaz_pozycje()

        # Przypisanie skrótów klawiszowych dla szybkości pracy
        self.root.bind('<Right>', lambda event: self.nastepny())
        self.root.bind('<Return>', lambda event: self.nastepny())
        self.root.bind('<Left>', lambda event: self.poprzedni())
        self.root.bind('<Control-s>', lambda event: self.zapisz_do_pliku())

    def wczytaj_dane(self):
        if not os.path.exists(PLIK_WEJSCIOWY):
            messagebox.showerror("Błąd",
                                 f"Nie znaleziono pliku {PLIK_WEJSCIOWY}!\nPoczekaj aż skrypt Qwena skończy pracę.")
            self.root.destroy()
            return

        with open(PLIK_WEJSCIOWY, 'r', encoding='utf-8') as f:
            for linia in f:
                if linia.strip():
                    self.dane.append(json.loads(linia))

    def zbuduj_ui(self):
        # Licznik postępu
        self.lbl_licznik = tk.Label(self.root, text="0 / 0", font=("Arial", 12, "bold"), fg="gray")
        self.lbl_licznik.pack(anchor="ne")

        # Oryginalna nazwa z paragonu (Surowe wejście)
        tk.Label(self.root, text="Oryginał z paragonu:", font=("Arial", 10)).pack(anchor="w")
        self.lbl_oryginal = tk.Label(self.root, text="-", font=("Consolas", 16, "bold"), fg="#D32F2F", wraplength=650,
                                     justify="left")
        self.lbl_oryginal.pack(fill="x", pady=(0, 20))

        # Wygenerowana nazwa przez Qwena (Do poprawy)
        tk.Label(self.root, text="Czysta nazwa / Kategoria (edytuj):", font=("Arial", 10)).pack(anchor="w")
        self.entry_wyjscie = tk.Entry(self.root, font=("Arial", 18), bg="#E8F5E9")
        self.entry_wyjscie.pack(fill="x", ipady=10)
        self.entry_wyjscie.focus_set()

        # Ramka na przyciski
        frame_btn = tk.Frame(self.root)
        self.root.bind()
        frame_btn.pack(fill="x", pady=30)

        tk.Button(frame_btn, text="<- Poprzedni (Strzałka w lewo)", command=self.poprzedni, font=("Arial", 10),
                  width=25).pack(side="left")
        tk.Button(frame_btn, text="Zapisz do pliku (Ctrl+S)", command=self.zapisz_do_pliku, font=("Arial", 10, "bold"),
                  bg="#2196F3", fg="white", width=20).pack(side="left", padx=20)
        tk.Button(frame_btn, text="Następny -> (Enter)", command=self.nastepny, font=("Arial", 10), width=25).pack(
            side="right")

    def pokaz_pozycje(self):
        if 0 <= self.obecny_indeks < len(self.dane):
            wiersz = self.dane[self.obecny_indeks]
            self.lbl_licznik.config(text=f"{self.obecny_indeks + 1} / {len(self.dane)}")
            self.lbl_oryginal.config(text=wiersz["wejscie"])

            self.entry_wyjscie.delete(0, tk.END)
            self.entry_wyjscie.insert(0, wiersz["wyjscie"])
            self.entry_wyjscie.select_range(0, tk.END)  # Automatyczne zaznaczenie tekstu ułatwia szybką poprawę

    def zapisz_obecny_stan(self):
        # Pobiera tekst z pola i zapisuje w pamięci przed przejściem dalej
        if 0 <= self.obecny_indeks < len(self.dane):
            self.dane[self.obecny_indeks]["wyjscie"] = self.entry_wyjscie.get().strip()

    def nastepny(self):
        self.zapisz_obecny_stan()
        if self.obecny_indeks < len(self.dane) - 1:
            self.obecny_indeks += 1
            self.pokaz_pozycje()
        else:
            messagebox.showinfo("Koniec", "To była ostatnia pozycja! Pamiętaj o zapisaniu pliku.")

    def poprzedni(self):
        self.zapisz_obecny_stan()
        if self.obecny_indeks > 0:
            self.obecny_indeks -= 1
            self.pokaz_pozycje()

    def zapisz_do_pliku(self):
        self.zapisz_obecny_stan()
        with open(PLIK_WYJSCIOWY, 'w', encoding='utf-8') as f:
            for wiersz in self.dane:
                f.write(json.dumps(wiersz, ensure_ascii=False) + "\n")
        messagebox.showinfo("Zapisano", f"Dane zapisane do {PLIK_WYJSCIOWY}!\nMożesz zamykać program.")


if __name__ == "__main__":
    root = tk.Tk()
    app = WeryfikatorKategorii(root)
    root.mainloop()