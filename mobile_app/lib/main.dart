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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0047AB),
          primary: const Color(0xFF0047AB),
          secondary: const Color(0xFF0047AB),
        ),
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
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0047AB),
        unselectedItemColor: Colors.grey,
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

  final ImagePicker _picker = ImagePicker();

  // ⚠️ Twój nowy, zunifikowany endpoint Multi-LoRA (bez "-dev")
  final String apiEndpoint = "https://TWOJ-ADRES-Z-MODAL.modal.run";

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

  Future<void> _zrobZdjecieZAParatu() async {
    try {
      List<String>? sciezkiZdjec = await CunningDocumentScanner.getPictures();

      if (sciezkiZdjec != null && sciezkiZdjec.isNotEmpty) {
        List<XFile> plikiDoKolejki = sciezkiZdjec
            .map((sciezka) => XFile(sciezka))
            .toList();

        _przetworzKolejke(plikiDoKolejki);
      }
    } catch (e) {
      _pokazKomunikat('Błąd skanera: $e', isError: true);
    }
  }

  // Akcja: Galeria / Pliki (multi-select)
  Future<void> _wybierzZGalerii() async {
    try {
      // Otwiera natywny wybierak zdjęć (Galeria / Pliki)
      final List<XFile> wybraneZdjecia = await _picker.pickMultiImage(
        imageQuality: 80,
      );

      if (wybraneZdjecia.isNotEmpty) {
        // Zrezygnowaliśmy z ImageCroppera!
        // Od razu pakujemy wybrane pliki do naszej kolejki wysyłkowej.
        _przetworzKolejke(wybraneZdjecia);
      }
    } catch (e) {
      _pokazKomunikat('Błąd galerii: $e', isError: true);
    }
  }

  Future<void> _przetworzKolejke(List<XFile> pliki) async {
    setState(() {
      _wszystkieParagony = pliki.length;
      _aktualnyParagon = 1;
      _trwaLadowanie = true;
    });

    for (var plik in pliki) {
      await _wyslijDoAI(File(plik.path));

      if (mounted && _aktualnyParagon < _wszystkieParagony) {
        setState(() {
          _aktualnyParagon++;
        });
      }
    }

    if (mounted) {
      setState(() {
        _trwaLadowanie = false;
        _aktualnyParagon = 0;
        _wszystkieParagony = 0;
      });
      _pokazKomunikat('Zakończono! Przetworzono ${pliki.length} paragon(ów).');
    }
  }

  Future<void> _wyslijDoAI(File plikZdjecia) async {
    try {
      // Proste zapytanie na nasz jeden silnik
      var request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
      request.files.add(
        await http.MultipartFile.fromPath('file', plikZdjecia.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['status'] == 'success') {
          String trwalaSciezka = await zapiszZdjecieLokalnie(plikZdjecia);

          // Wpisujemy model na sztywno
          await _zapiszDoBazyDanych(
            jsonResponse['dane'],
            trwalaSciezka,
            'Multi-LoRA',
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

  Future<void> _zapiszDoBazyDanych(
    Map<String, dynamic> dane,
    String? sciezkaZdjecia,
    String? modelAi,
  ) async {
    double kwota =
        double.tryParse(
          dane['kwota_calkowita']?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0.0;

    int paragonId = await DatabaseHelper.instance.dodajParagon({
      'sklep': dane['sklep'] ?? 'Nieznany sklep',
      'data': dane['data_czas'] ?? 'Brak daty',
      'kwota': kwota,
      'image_local_path': sciezkaZdjecia,
      'ai_model_used': modelAi,
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
    // Usunięty zbędny Stack, czysty wyśrodkowany interfejs
    return Center(
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
    );
  }
}

// ==========================================
// ZAKŁADKA 2: EKRAN PARAGONÓW
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
    // Usunięty zbędny pasek filtrowania
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
                  backgroundColor: Color(0xFF0047AB),
                  child: Icon(Icons.receipt_long, color: Colors.white),
                ),
                title: Text(
                  paragon['sklep'] ?? 'Nieznany sklep',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text('${paragon['data'] ?? 'Brak daty'}'),
                trailing: Text(
                  '${paragon['kwota'].toStringAsFixed(2)} zł',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                onTap: () async {
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
  String _sortowanie = 'data_desc';

  @override
  void initState() {
    super.initState();
    _odswiezBaze();
  }

  void _odswiezBaze() {
    setState(() {
      _pozycje = DatabaseHelper.instance.pobierzWszystkiePozycje().then((dane) {
        var lista = List<Map<String, dynamic>>.from(dane);
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
                      _odswiezBaze();
                    });
                  }
                },
              ),
            ],
          ),
        ),
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
                      // Usunięty dopisek o modelu
                      subtitle: Text('${p['sklep']} • ${p['data']}'),
                      trailing: Text(
                        '${p['cena'].toStringAsFixed(2)} zł',
                        style: const TextStyle(
                          color: Color(0xFF0047AB),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () async {
                        final paragonId = p['paragon_id'];
                        final pelnyParagon = await DatabaseHelper.instance
                            .pobierzPojedynczyParagon(paragonId);

                        if (pelnyParagon != null && context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EkranSzczegolowParagonu(
                                paragon: pelnyParagon,
                              ),
                            ),
                          );
                          _odswiezBaze();
                        }
                      },
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

        double sumaCalkowita = paragony.fold(
          0,
          (sum, p) => sum + (p['kwota'] as num),
        );

        Map<String, dynamic>? najdrozszyProdukt;
        if (pozycje.isNotEmpty) {
          najdrozszyProdukt = pozycje.reduce(
            (a, b) => (a['cena'] as num) > (b['cena'] as num) ? a : b,
          );
        }

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

        Map<String, double> sklepyWydatki = {};
        for (var p in paragony) {
          String sklep = p['sklep'] ?? 'Inne';
          sklepyWydatki[sklep] =
              (sklepyWydatki[sklep] ?? 0) + (p['kwota'] as num);
        }
        var posortowaneSklepy = sklepyWydatki.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        var topSklepy = posortowaneSklepy.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
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
// EKRAN SZCZEGÓŁÓW PARAGONU
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
                await DatabaseHelper.instance.aktualizujPozycje(
                  pozycja['id'],
                  nazwaCtrl.text,
                  nowaCena,
                );
                await DatabaseHelper.instance.przeliczSumeParagonu(
                  widget.paragon['id'],
                );
                if (context.mounted) Navigator.pop(context);
                _odswiezPozycje();
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _usunCalyParagon() async {
    await DatabaseHelper.instance.usunParagon(widget.paragon['id']);
    if (context.mounted) Navigator.pop(context, true);
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
            itemCount: pozycje.length + 1,
            itemBuilder: (context, index) {
              if (index == pozycje.length) {
                String? sciezkaZdjecia = widget.paragon['image_local_path'];
                // Zniknęła stąd sekcja wyświetlająca użytą nazwę modelu

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const Divider(thickness: 2),

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
