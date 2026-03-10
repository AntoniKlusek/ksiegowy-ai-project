import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'image_helper.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_cropper/image_cropper.dart';

void main() {
  runApp(const KsiegowyApp());
}

class KsiegowyApp extends StatelessWidget {
  const KsiegowyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Księgowy AI',
      debugShowCheckedModeBanner: false, // Usuwamy irytujący pasek "DEBUG"
      theme: ThemeData(
        // Nasz główny, jasnoniebieski motyw
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0047AB),
          primary: const Color(0xFF0047AB),
          secondary: const Color(0xFF0047AB),
        ),
        // Bardzo jasne tło, żeby kafelki paragonów ładnie się odcinały
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
        useMaterial3: true,
      ),
      home: const EkranGlowny(),
    );
  }
}

class EkranGlowny extends StatefulWidget {
  const EkranGlowny({super.key});

  @override
  State<EkranGlowny> createState() => _EkranGlownyState();
}

class _EkranGlownyState extends State<EkranGlowny> {
  int _obecnyIndeks = 0;

  // Tutaj trzymamy nasze 3 ekrany
  static final List<Widget> _ekrany = <Widget>[
    const EkranSkanera(),
    const EkranParagonow(),
    const EkranBazy(),
    const EkranStatystyk(),
  ];

  void _zmianaZakladki(int index) {
    setState(() {
      _obecnyIndeks = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Księgowy AI',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0047AB),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(child: _ekrany.elementAt(_obecnyIndeks)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType
            .fixed, // <--- To zmusza pasek do posłuszeństwa
        backgroundColor: Colors.white, // <--- Białe tło paska
        selectedItemColor: const Color(0xFF0047AB), // Nasz kobalt
        unselectedItemColor: Colors.grey, // <--- Szare nieaktywne ikony
        showUnselectedLabels: true,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Skaner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Paragony',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Baza'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Raporty',
          ),
        ],
        currentIndex: _obecnyIndeks,
        onTap: _zmianaZakladki,
      ),
    );
  }
}

// ==========================================
// ZAKŁADKA 1: SKANER
// ==========================================
class EkranSkanera extends StatefulWidget {
  const EkranSkanera({super.key});

  @override
  State<EkranSkanera> createState() => _EkranSkaneraState();
}

class _EkranSkaneraState extends State<EkranSkanera> {
  bool _trwaLadowanie = false;
  int _aktualnyParagon = 0;
  int _wszystkieParagony = 0;
  String _wybranyModel = 'Qwen';

  final ImagePicker _picker = ImagePicker();

  // TODO: Podmień na swój własny adres z wdrożenia Modal
  final String baseUrl = "https://TWOJ-ADRES-Z-MODAL.modal.run";
  final Color kobalt = const Color(0xFF0047AB);

  void _pokazMenuWyboru() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Wybierz źródło zdjęcia:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: kobalt),
                title: const Text('Zrób JEDNO zdjęcie aparatem'),
                onTap: () {
                  Navigator.of(context).pop();
                  _zrobZdjecieZAParatu();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: kobalt),
                title: const Text('Wybierz KILKA z galerii'),
                onTap: () {
                  Navigator.of(context).pop();
                  _wybierzZGalerii();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Akcja: Aparat (zawsze 1 zdjęcie)
  Future<void> _zrobZdjecieZAParatu() async {
    try {
      // Odpalamy natywny skaner (true = pozwala na edycję rogów)
      List<String>? sciezkiZdjec = await CunningDocumentScanner.getPictures();

      if (sciezkiZdjec != null && sciezkiZdjec.isNotEmpty) {
        // Magia: Konwertujemy tekstowe ścieżki naiekty XFile,
        // żeby Twój system kolejkowania nawet nie zauważył różnicy!
        List<XFile> plikiDoKolejki = sciezkiZdjec
            .map((sciezka) => XFile(sciezka))
            .toList();

        _przetworzKolejke(plikiDoKolejki);
      }
    } catch (e) {
      _pokazKomunikat('Błąd skanera: $e', isError: true);
    }
  }

  // Akcja: Galeria (multi-select)
  Future<void> _wybierzZGalerii() async {
    try {
      final List<XFile> wybraneZdjecia = await _picker.pickMultiImage(
        imageQuality: 80,
      );

      if (wybraneZdjecia.isNotEmpty) {
        List<XFile> przycieteZdjecia = [];

        // Pętla przechodząca przez wybrane zdjęcia i pozwalająca na ich docięcie
        for (var zdjecie in wybraneZdjecia) {
          CroppedFile? przycietyPlik = await ImageCropper().cropImage(
            sourcePath: zdjecie.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Przytnij Paragon',
                toolbarColor: kobalt,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false,
              ),
              IOSUiSettings(title: 'Przytnij Paragon'),
            ],
          );

          if (przycietyPlik != null) {
            przycieteZdjecia.add(XFile(przycietyPlik.path));
          }
        }

        if (przycieteZdjecia.isNotEmpty) {
          _przetworzKolejke(przycieteZdjecia);
        }
      }
    } catch (e) {
      _pokazKomunikat('Błąd galerii: $e', isError: true);
    }
  }

  // Silnik Kolejkowania
  Future<void> _przetworzKolejke(List<XFile> pliki) async {
    setState(() {
      _wszystkieParagony = pliki.length;
      _aktualnyParagon = 1;
      _trwaLadowanie = true;
    });

    for (var plik in pliki) {
      await _wyslijDoAI(File(plik.path));

      // Po każdym wysłanym pliku zwiększamy licznik (chyba że to już ostatni)
      if (mounted && _aktualnyParagon < _wszystkieParagony) {
        setState(() {
          _aktualnyParagon++;
        });
      }
    }

    // Koniec pętli = wyłączamy ładowanie
    if (mounted) {
      setState(() {
        _trwaLadowanie = false;
        _aktualnyParagon = 0;
        _wszystkieParagony = 0;
      });
      _pokazKomunikat('Zakończono! Przetworzono ${pliki.length} paragon(ów).');
    }
  }

  // Wysyła jeden konkretny plik do FastAPI
  Future<void> _wyslijDoAI(File plikZdjecia) async {
    try {
      // MAGIA 1: Wybieramy adres serwera na podstawie przełącznika!
      String baseUrl =
          "https://antoniklusek--ksiegowy-ai-v4-dual-fastapi-endpoint.modal.run";

      String urlDocelowy = _wybranyModel == 'Qwen'
          ? "$baseUrl/skanuj_qwen"
          : "$baseUrl/skanuj_paligemma";

      var request = http.MultipartRequest('POST', Uri.parse(urlDocelowy));
      request.files.add(
        await http.MultipartFile.fromPath('file', plikZdjecia.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['status'] == 'success') {
          String trwalaSciezka = await zapiszZdjecieLokalnie(plikZdjecia);

          // MAGIA 2: Zapisujemy do bazy nazwę modelu, który to przetworzył!
          await _zapiszDoBazyDanych(
            jsonResponse['dane'],
            trwalaSciezka,
            _wybranyModel,
          );
        } else {
          _pokazKomunikat(
            'Błąd AI przy paragonie $_aktualnyParagon: ${jsonResponse['message']}',
            isError: true,
          );
        }
      }
    } catch (e) {
      _pokazKomunikat(
        'Błąd sieci przy paragonie $_aktualnyParagon: $e',
        isError: true,
      );
    }
  }

  // "Wiadro" na dane - zapis do bazy SQLite
  // Dodaliśmy argumenty: sciezkaZdjecia i modelAi
  Future<void> _zapiszDoBazyDanych(
    Map<String, dynamic> dane,
    String? sciezkaZdjecia,
    String? modelAi,
  ) async {
    // Zabezpieczenie na wypadek przecinka zamiast kropki
    double kwota =
        double.tryParse(
          dane['kwota_calkowita']?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0.0;

    int paragonId = await DatabaseHelper.instance.dodajParagon({
      'sklep': dane['sklep'] ?? 'Nieznany sklep',
      'data': dane['data_czas'] ?? 'Brak daty',
      'kwota': kwota,
      'image_local_path': sciezkaZdjecia, // <--- NOWE (Ścieżka do zdjęcia)
      'ai_model_used':
          modelAi, // <--- NOWE (Informacja, czy to Qwen, czy PaliGemma)
    });

    if (dane['pozycje'] != null) {
      for (var pozycja in dane['pozycje']) {
        double cena =
            double.tryParse(
              pozycja['cena']?.toString().replaceAll(',', '.') ?? '0',
            ) ??
            0.0;
        await DatabaseHelper.instance.dodajPozycje({
          'paragon_id': paragonId,
          'nazwa': pozycja['nazwa'] ?? 'Nieznany produkt',
          'cena': cena,
        });
      }
    }
  }

  // Wyświetlanie powiadomień (SnackBar) na dole ekranu
  void _pokazKomunikat(String wiadomosc, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wiadomosc),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // WARSTWA 1: Twój wyśrodkowany, główny interfejs (na samym spodzie)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.document_scanner, size: 100, color: kobalt),
              const SizedBox(height: 20),
              const Text(
                'Księgowy AI czeka',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Zrób zdjęcie lub wybierz KILKA z galerii,\na sztuczna inteligencja zrobi resztę.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Zmieniony interfejs ładowania z licznikiem
              _trwaLadowanie
                  ? Column(
                      children: [
                        CircularProgressIndicator(color: kobalt),
                        const SizedBox(height: 15),
                        Text(
                          _wszystkieParagony > 1
                              ? "Przetwarzanie paragonu $_aktualnyParagon z $_wszystkieParagony..."
                              : "AI analizuje paragon, proszę czekać...",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: _pokazMenuWyboru,
                      icon: const Icon(Icons.add_a_photo, color: Colors.white),
                      label: const Text(
                        'Skanuj Paragony',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kobalt,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
            ],
          ),
        ),

        // WARSTWA 2: Pływający przycisk w prawym górnym rogu
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            // Chroni przed wejściem pod notch/baterię
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kobalt.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _wybranyModel, // To Twoja zmienna z Krok 1
                  icon: Icon(Icons.keyboard_arrow_down, color: kobalt),
                  style: TextStyle(
                    color: kobalt,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  items: ['Qwen', 'PaliGemma'].map((String model) {
                    return DropdownMenuItem<String>(
                      value: model,
                      child: Row(
                        children: [
                          Icon(
                            model == 'Qwen' ? Icons.memory : Icons.bolt,
                            size: 16,
                            color: kobalt,
                          ),
                          const SizedBox(width: 8),
                          Text(model),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? nowyModel) {
                    if (nowyModel != null) {
                      setState(() {
                        _wybranyModel = nowyModel;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// ZAKŁADKA 2: PARAGONY (HISTORIA)
// ==========================================
class EkranParagonow extends StatefulWidget {
  const EkranParagonow({super.key});

  @override
  State<EkranParagonow> createState() => _EkranParagonowState();
}

class _EkranParagonowState extends State<EkranParagonow> {
  late Future<List<Map<String, dynamic>>> _paragony;

  @override
  void initState() {
    super.initState();
    _odswiezBaze();
  }

  void _odswiezBaze() {
    setState(() {
      _paragony = DatabaseHelper.instance.pobierzWszystkieParagony();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _paragony,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0047AB)),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Błąd bazy: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Brak paragonów w bazie. Zeskanuj coś!',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        final paragony = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: paragony.length,
          itemBuilder: (context, index) {
            final paragon = paragony[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0047AB), // Nasz kobalt
                  child: Icon(Icons.receipt_long, color: Colors.white),
                ),
                title: Text(
                  paragon['sklep'] ?? 'Nieznany sklep',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(paragon['data'] ?? 'Brak daty'),
                trailing: Text(
                  '${paragon['kwota'].toStringAsFixed(2)} zł',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                onTap: () async {
                  // Otwiera nowy ekran. Czeka na powrót. Jeśli wrócisz, odświeża bazę.
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EkranSzczegolowParagonu(paragon: paragon),
                    ),
                  );
                  _odswiezBaze();
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// ZAKŁADKA 3: BAZA PRODUKTÓW (ANALITYKA)
// ==========================================
class EkranBazy extends StatefulWidget {
  const EkranBazy({super.key});

  @override
  State<EkranBazy> createState() => _EkranBazyState();
}

class _EkranBazyState extends State<EkranBazy> {
  late Future<List<Map<String, dynamic>>> _pozycje;
  String _sortowanie = 'data_desc'; // Domyślne sortowanie

  @override
  void initState() {
    super.initState();
    _odswiezBaze();
  }

  void _odswiezBaze() {
    setState(() {
      _pozycje = DatabaseHelper.instance.pobierzWszystkiePozycje().then((dane) {
        // Tworzymy kopię listy, żeby móc ją bezpiecznie sortować
        var lista = List<Map<String, dynamic>>.from(dane);

        // Magia sortowania
        if (_sortowanie == 'cena_desc') {
          lista.sort((a, b) => (b['cena'] as num).compareTo(a['cena'] as num));
        } else if (_sortowanie == 'cena_asc') {
          lista.sort((a, b) => (a['cena'] as num).compareTo(b['cena'] as num));
        } else if (_sortowanie == 'nazwa_asc') {
          lista.sort(
            (a, b) => (a['nazwa'] ?? '').toString().compareTo(
              (b['nazwa'] ?? '').toString(),
            ),
          );
        } else {
          // data_desc (Domyślnie najnowsze)
          lista.sort(
            (a, b) => (b['data'] ?? '').toString().compareTo(
              (a['data'] ?? '').toString(),
            ),
          );
        }
        return lista;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pasek narzędzi z opcją sortowania
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sortuj po:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0047AB),
                ),
              ),
              DropdownButton<String>(
                value: _sortowanie,
                underline: Container(height: 2, color: const Color(0xFF0047AB)),
                items: const [
                  DropdownMenuItem(
                    value: 'data_desc',
                    child: Text('Najnowsze'),
                  ),
                  DropdownMenuItem(
                    value: 'cena_desc',
                    child: Text('Od najdroższych'),
                  ),
                  DropdownMenuItem(
                    value: 'cena_asc',
                    child: Text('Od najtańszych'),
                  ),
                  DropdownMenuItem(
                    value: 'nazwa_asc',
                    child: Text('Alfabetycznie (A-Z)'),
                  ),
                ],
                onChanged: (String? nowaWartosc) {
                  if (nowaWartosc != null) {
                    setState(() {
                      _sortowanie = nowaWartosc;
                      _odswiezBaze(); // Przeładuj listę po zmianie opcji
                    });
                  }
                },
              ),
            ],
          ),
        ),

        // Lista produktów
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _pozycje,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0047AB)),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Błąd bazy: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Brak produktów w bazie. Zeskanuj pierwszy paragon!',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final pozycje = snapshot.data!;
              return ListView.builder(
                itemCount: pozycje.length,
                itemBuilder: (context, index) {
                  final p = pozycje[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(
                        p['nazwa'] ?? 'Nieznany produkt',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${p['sklep']} • ${p['data']}'),
                      trailing: Text(
                        '${p['cena'].toStringAsFixed(2)} zł',
                        style: const TextStyle(
                          color: Color(0xFF0047AB),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// ZAKŁADKA 4: RAPORTY I STATYSTYKI
// ==========================================
class EkranStatystyk extends StatelessWidget {
  const EkranStatystyk({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // Pobieramy obie tabele naraz!
      future: Future.wait([
        DatabaseHelper.instance.pobierzWszystkieParagony(),
        DatabaseHelper.instance.pobierzWszystkiePozycje(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0047AB)),
          );
        } else if (!snapshot.hasData || snapshot.data![0].isEmpty) {
          return const Center(
            child: Text(
              'Zeskanuj paragony, aby zobaczyć statystyki.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final paragony = snapshot.data![0] as List<Map<String, dynamic>>;
        final pozycje = snapshot.data![1] as List<Map<String, dynamic>>;

        // --- MATEMATYKA W LOCIE ---

        // 1. Łączna suma wydatków
        double sumaCalkowita = paragony.fold(
          0,
          (sum, p) => sum + (p['kwota'] as num),
        );

        // 2. Najdroższy produkt
        Map<String, dynamic>? najdrozszyProdukt;
        if (pozycje.isNotEmpty) {
          najdrozszyProdukt = pozycje.reduce(
            (a, b) => (a['cena'] as num) > (b['cena'] as num) ? a : b,
          );
        }

        // 3. Najczęstszy produkt
        Map<String, int> czestotliwosc = {};
        for (var p in pozycje) {
          String nazwa = p['nazwa'] ?? 'Nieznany';
          czestotliwosc[nazwa] = (czestotliwosc[nazwa] ?? 0) + 1;
        }
        String najczestszyProdukt = "Brak";
        if (czestotliwosc.isNotEmpty) {
          var sortedKeys = czestotliwosc.keys.toList()
            ..sort((a, b) => czestotliwosc[b]!.compareTo(czestotliwosc[a]!));
          najczestszyProdukt =
              "${sortedKeys.first} (${czestotliwosc[sortedKeys.first]}x)";
        }

        // 4. Top 5 sklepów (grupowanie po kwocie)
        Map<String, double> sklepyWydatki = {};
        for (var p in paragony) {
          String sklep = p['sklep'] ?? 'Inne';
          sklepyWydatki[sklep] =
              (sklepyWydatki[sklep] ?? 0) + (p['kwota'] as num);
        }
        var posortowaneSklepy = sklepyWydatki.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        var topSklepy = posortowaneSklepy.take(5).toList();

        // --- INTERFEJS KART ---
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // KARTA: Łączne wydatki
            Card(
              color: const Color(0xFF0047AB),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Łączne wydatki',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${sumaCalkowita.toStringAsFixed(2)} zł',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // KARTA: Ciekawostki
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔎 Ciekawostki',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0047AB),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: const Text('Najczęstszy produkt'),
                      subtitle: Text(
                        najczestszyProdukt,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.monetization_on,
                        color: Colors.redAccent,
                      ),
                      title: const Text('Najdroższy produkt'),
                      subtitle: Text(
                        najdrozszyProdukt != null
                            ? '${najdrozszyProdukt['nazwa']} (${najdrozszyProdukt['cena']} zł)'
                            : 'Brak',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // KARTA: Top Sklepy
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🛒 Top Sklepy (Wydatki)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0047AB),
                      ),
                    ),
                    const Divider(),
                    ...topSklepy
                        .map(
                          (entry) => ListTile(
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              '${entry.value.toStringAsFixed(2)} zł',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// EKRAN SZCZEGÓŁÓW PARAGONU (EDYCJA I USUWANIE)
// ==========================================
class EkranSzczegolowParagonu extends StatefulWidget {
  final Map<String, dynamic> paragon;
  const EkranSzczegolowParagonu({super.key, required this.paragon});

  @override
  State<EkranSzczegolowParagonu> createState() =>
      _EkranSzczegolowParagonuState();
}

class _EkranSzczegolowParagonuState extends State<EkranSzczegolowParagonu> {
  late Future<List<Map<String, dynamic>>> _pozycje;

  @override
  void initState() {
    super.initState();
    _odswiezPozycje();
  }

  void _odswiezPozycje() {
    setState(() {
      _pozycje = DatabaseHelper.instance.pobierzPozycjeDlaParagonu(
        widget.paragon['id'],
      );
    });
  }

  // Okienko do edycji produktu
  void _edytujPozycje(Map<String, dynamic> pozycja) {
    TextEditingController nazwaCtrl = TextEditingController(
      text: pozycja['nazwa'],
    );
    TextEditingController cenaCtrl = TextEditingController(
      text: pozycja['cena'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edytuj produkt',
          style: TextStyle(color: Color(0xFF0047AB)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nazwaCtrl,
              decoration: const InputDecoration(labelText: 'Nazwa produktu'),
            ),
            TextField(
              controller: cenaCtrl,
              decoration: const InputDecoration(labelText: 'Cena (zł)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0047AB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              double? nowaCena = double.tryParse(
                cenaCtrl.text.replaceAll(',', '.'),
              );
              if (nowaCena != null && nazwaCtrl.text.isNotEmpty) {
                // Aktualizujemy w bazie produkt i przeliczamy paragon!
                await DatabaseHelper.instance.aktualizujPozycje(
                  pozycja['id'],
                  nazwaCtrl.text,
                  nowaCena,
                );
                await DatabaseHelper.instance.przeliczSumeParagonu(
                  widget.paragon['id'],
                );
                if (context.mounted) Navigator.pop(context);
                _odswiezPozycje(); // Odśwież widok
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  // Usuwanie paragonu
  void _usunCalyParagon() async {
    await DatabaseHelper.instance.usunParagon(widget.paragon['id']);
    if (context.mounted)
      Navigator.pop(context, true); // true = sygnał do odświeżenia listy
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.paragon['sklep']}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0047AB),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () {
              // Potwierdzenie przed usunięciem
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Usunąć paragon?'),
                  content: const Text(
                    'Zostanie usunięty bezpowrotnie. Jesteś pewien?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Nie'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _usunCalyParagon();
                      },
                      child: const Text(
                        'Tak, usuń',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pozycje,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pozycje = snapshot.data!;

          return ListView.builder(
            // DODAJEMY +1 DO DŁUGOŚCI LISTY NA NASZ PANEL ZE ZDJĘCIEM
            itemCount: pozycje.length + 1,
            itemBuilder: (context, index) {
              // --- NOWOŚĆ: STOPKA LISTY (JEŚLI TO OSTATNI ELEMENT) ---
              if (index == pozycje.length) {
                // Wyciągamy dane prosto z obiektu widget.paragon
                String? sciezkaZdjecia = widget.paragon['image_local_path'];
                String? uzytyModel = widget.paragon['ai_model_used'];

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const Divider(thickness: 2),

                      // Nazwa użytego modelu
                      if (uzytyModel != null && uzytyModel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                uzytyModel == 'Qwen'
                                    ? Icons.memory
                                    : Icons.bolt,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Zeskanowano przez: $uzytyModel',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Sekcja ze zdjęciem
                      if (sciezkaZdjecia != null &&
                          sciezkaZdjecia.isNotEmpty &&
                          File(sciezkaZdjecia).existsSync()) ...[
                        const Text(
                          'Oryginalny skan:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Image.file(
                              File(sciezkaZdjecia),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Brak zdjęcia dla tego paragonu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              // --- KONIEC NOWOŚCI ---

              // --- TWÓJ ORYGINALNY KOD DLA POZYCJI (Bez zmian) ---
              final pozycja = pozycje[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  title: Text(
                    pozycja['nazwa'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '${pozycja['cena'].toStringAsFixed(2)} zł',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onTap: () => _edytujPozycje(pozycja),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
