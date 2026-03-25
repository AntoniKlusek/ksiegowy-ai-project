import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import '../image_helper.dart';
import '../app_theme.dart';

class EkranSkanera extends StatefulWidget {
  const EkranSkanera({super.key});

  @override
  State<EkranSkanera> createState() => _EkranSkaneraState();
}

class _EkranSkaneraState extends State<EkranSkanera> {
  bool _trwaLadowanie = false;
  int _aktualnyParagon = 0;
  int _wszystkieParagony = 0;
  String _aktualnyStatus = "Inicjowanie połączenia...";
  double _aktualnyZasieg = 0.0;
  int _liczbaOtrzymanychInfo = 0;
  int _animDurationMs = 5000;
  final ImagePicker _picker = ImagePicker();

  final String apiEndpoint =
      "https://[YOUR_BACKEND_PLACEHOLDER_URL]/skanuj";

  void _pokazMenuWyboru() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Dodaj paragon', style: GoogleFonts.manrope(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface,
            )),
            const SizedBox(height: 4),
            Text('Wybierz źródło zdjęcia', style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.onSurfaceVariant,
            )),
            const SizedBox(height: 24),
            _SheetOption(
              icon: Icons.document_scanner_outlined,
              label: 'Skanuj aparat (dokument)',
              subtitle: 'Automatyczna korekcja perspektywy',
              onTap: () { Navigator.pop(ctx); _zrobZdjecieZAParatu(); },
            ),
            const SizedBox(height: 12),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Galeria — kilka zdjęć',
              subtitle: 'Multi-select z biblioteki',
              onTap: () { Navigator.pop(ctx); _wybierzZGalerii(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _zrobZdjecieZAParatu() async {
    try {
      List<String>? sciezkiZdjec = await CunningDocumentScanner.getPictures();
      if (sciezkiZdjec != null && sciezkiZdjec.isNotEmpty) {
        _przetworzKolejke(sciezkiZdjec.map((s) => XFile(s)).toList());
      }
    } catch (e) {
      _pokazKomunikat('Błąd skanera: $e', isError: true);
    }
  }

  Future<void> _wybierzZGalerii() async {
    try {
      final List<XFile> wybrane = await _picker.pickMultiImage(imageQuality: 50);
      if (wybrane.isNotEmpty) _przetworzKolejke(wybrane);
    } catch (e) {
      _pokazKomunikat('Błąd galerii: $e', isError: true);
    }
  }

  Future<void> _przetworzKolejke(List<XFile> pliki) async {
    setState(() {
      _wszystkieParagony = pliki.length;
      _aktualnyParagon = 1;
      _aktualnyStatus = "Inicjowanie połączenia...";
      _trwaLadowanie = true;
    });
    for (var plik in pliki) {
      await _wyslijDoAI(File(plik.path));
      
      // Delay so the user can see the progress bar hit 100% and read "Zapisano pomyślnie"
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted && _aktualnyParagon < _wszystkieParagony) {
        setState(() => _aktualnyParagon++);
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
      print("Wysyłam (Streaming SSE) do AI... ${plikZdjecia.path}");
      setState(() {
        _aktualnyStatus = "Inicjowanie połączenia z serwerem...";
        _aktualnyZasieg = 0.1;
        _liczbaOtrzymanychInfo = 0;
        _animDurationMs = 5000;
      });
      
      var request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
      request.files.add(await http.MultipartFile.fromPath('file', plikZdjecia.path));
      
      var client = http.Client();
      var response = await client.send(request);
      
      print("Odpowiedź API SSE status: ${response.statusCode}");
      if (response.statusCode == 200) {
        await for (var line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.trim().isEmpty) continue;
          if (line.startsWith('data: ')) {
            var dataStr = line.substring(6);
            try {
              var json = jsonDecode(dataStr);
              if (json['status'] == 'info') {
                if (mounted) {
                  setState(() {
                    _aktualnyStatus = json['wiadomosc'] ?? 'Przetwarzanie...';
                    _liczbaOtrzymanychInfo++;
                    double newZasieg = 0.1 + (_liczbaOtrzymanychInfo * 0.25);
                    if (newZasieg > 0.95) newZasieg = 0.95;
                    _aktualnyZasieg = newZasieg;
                  });
                }
              } else if (json['status'] == 'sukces') {
                var wynik = json['wynik'] ?? json['dane'];
                print("AI Sukces z SSE: $wynik");
                String trwalaSciezka = await zapiszZdjecieLokalnie(plikZdjecia);
                await _zapiszDoBazy(wynik, trwalaSciezka, 'SSE-Model');
                if (mounted) {
                  setState(() {
                    _aktualnyStatus = "Zapisano pomyślnie w bazie!";
                    _aktualnyZasieg = 1.0;
                    _animDurationMs = 800; // Szybki skok na 100%
                  });
                }
              } else if (json['status'] == 'error') {
                _pokazKomunikat('Błąd od AI serwera (paragon $_aktualnyParagon): ${json['wiadomosc'] ?? 'Brak szczegółów'}', isError: true);
              }
            } catch (e) {
              print('Błąd parsowania SSE chunk: $line -> $e');
            }
          }
        }
      } else {
        _pokazKomunikat('Błąd serwera HTTP ${response.statusCode}', isError: true);
      }
      client.close();
    } catch (e, stack) {
      print("WYJĄTEK AI SSE: $e\n$stack");
      _pokazKomunikat('Błąd połączenia strumieniowego $_aktualnyParagon: $e', isError: true);
    }
  }

  Future<void> _zapiszDoBazy(Map<String, dynamic>? dane, String? sciezka, String? model) async {
    if (dane == null) {
      print("Błąd: dane == null");
      _pokazKomunikat('Błąd: API nie zwróciło danych paragonu', isError: true);
      return;
    }
    try {
      double kwota = double.tryParse(dane['kwota_calkowita']?.toString().replaceAll(',', '.') ?? '0') ?? 0.0;
      print("Dodawanie paragonu: sklep=${dane['sklep']}, data=${dane['data_czas']}, kwota=$kwota");
      int paragonId = await DatabaseHelper.instance.dodajParagon({
        'sklep': dane['sklep'] ?? 'Nieznany sklep',
        'data': dane['data_czas'] ?? 'Brak daty',
        'kwota': kwota,
        'image_local_path': sciezka,
        'ai_model_used': model,
      });
      if (dane['pozycje'] != null && dane['pozycje'] is List) {
        print("Dodawanie ${dane['pozycje'].length} pozycji dla paragonId=$paragonId");
        for (var p in dane['pozycje']) {
          double cena = double.tryParse(p['cena']?.toString().replaceAll(',', '.') ?? '0') ?? 0.0;
          await DatabaseHelper.instance.dodajPozycje({
            'paragon_id': paragonId,
            'nazwa': p['nazwa'] ?? 'Nieznany produkt',
            'cena': cena,
          });
        }
      }
      print("Zapis do bazy udany.");
      DatabaseHelper.instance.notifyDBChanged();
    } catch(e, stack) {
      print("BŁĄD ZAPISU DO BAZY: $e\n$stack");
      _pokazKomunikat('Błąd sqflite: $e', isError: true);
    }
  }

  void _pokazKomunikat(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 14)),
      backgroundColor: isError ? AppColors.error : AppColors.tertiary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon area
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.document_scanner, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              'Skanuj paragon',
              style: GoogleFonts.manrope(
                fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aparat lub galeria — AI wyciągnie dane i zapisze je w bazie automatycznie.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 48),
            if (_trwaLadowanie) ...[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _aktualnyZasieg),
                duration: Duration(milliseconds: _animDurationMs),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: AppColors.surfaceContainerHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Text('${(value * 100).toInt()}%', 
                            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                _wszystkieParagony > 1
                    ? '[$_aktualnyParagon/$_wszystkieParagony] $_aktualnyStatus'
                    : _aktualnyStatus,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ] else
              _GradientButton(
                label: 'Skanuj Paragony',
                icon: Icons.add_a_photo_outlined,
                onPressed: _pokazMenuWyboru,
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white,
            )),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface,
                  )),
                  Text(subtitle, style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.onSurfaceVariant,
                  )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
