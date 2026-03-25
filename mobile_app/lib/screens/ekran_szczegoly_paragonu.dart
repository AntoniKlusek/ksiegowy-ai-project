import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import '../app_theme.dart';

class EkranSzczegolowParagonu extends StatefulWidget {
  final Map<String, dynamic> paragon;
  const EkranSzczegolowParagonu({super.key, required this.paragon});

  @override
  State<EkranSzczegolowParagonu> createState() => _EkranSzczegolowParagonuState();
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
      _pozycje = DatabaseHelper.instance.pobierzPozycjeDlaParagonu(widget.paragon['id']);
    });
  }

  void _edytujPozycje(Map<String, dynamic> pozycja) {
    final nazwaCtrl = TextEditingController(text: pozycja['nazwa']);
    final cenaCtrl = TextEditingController(text: pozycja['cena'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edytuj produkt', style: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary,
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nazwaCtrl,
              style: GoogleFonts.inter(color: AppColors.onSurface),
              decoration: InputDecoration(
                labelText: 'Nazwa produktu',
                labelStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cenaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(color: AppColors.onSurface),
              decoration: InputDecoration(
                labelText: 'Cena (zł)',
                labelStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Potwierdzenie przed usunięciem by było bezpiecznie, ale uprośćmy - to szybka akcja!
              await DatabaseHelper.instance.usunPozycje(pozycja['id']);
              await DatabaseHelper.instance.przeliczSumeParagonu(widget.paragon['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              _odswiezPozycje();
            },
            child: Text('Usuń', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Anuluj', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              double? nowaCena = double.tryParse(cenaCtrl.text.replaceAll(',', '.'));
              if (nowaCena != null && nazwaCtrl.text.isNotEmpty) {
                await DatabaseHelper.instance.aktualizujPozycje(pozycja['id'], nazwaCtrl.text, nowaCena);
                await DatabaseHelper.instance.przeliczSumeParagonu(widget.paragon['id']);
                if (ctx.mounted) Navigator.pop(ctx);
                _odswiezPozycje();
              }
            },
            child: Text('Zapisz', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceBetween,
      ),
    );
  }

  void _pokazDialogUsun() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Usunąć paragon?', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text('Zostanie usunięty bezpowrotnie.', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Nie', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await DatabaseHelper.instance.usunParagon(widget.paragon['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) Navigator.pop(context, true);
            },
            child: Text('Usuń', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String sklep = widget.paragon['sklep'] ?? 'Paragon';
    final String data = widget.paragon['data'] ?? '';
    final double kwota = (widget.paragon['kwota'] as num?)?.toDouble() ?? 0.0;
    final String? sciezkaZdjecia = widget.paragon['image_local_path'];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sklep, style: GoogleFonts.manrope(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.onSurface,
            )),
            if (data.isNotEmpty)
              Text(data, style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _pokazDialogUsun,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pozycje,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final pozycje = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Suma', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                          Text('${kwota.toStringAsFixed(2)} zł', style: GoogleFonts.manrope(
                            fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white,
                          )),
                          Text('${pozycje.length} pozycji', style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white60,
                          )),
                        ],
                      ),
                    ),
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pozycje
              Text('Pozycje', style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface,
              )),
              const SizedBox(height: 10),
              ...pozycje.map((pozycja) => GestureDetector(
                onTap: () => _edytujPozycje(pozycja),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(pozycja['nazwa'] ?? '', style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface,
                        )),
                      ),
                      Text('${(pozycja['cena'] as num).toStringAsFixed(2)} zł',
                        style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.primaryContainer)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.outline),
                    ],
                  ),
                ),
              )),

              // Zdjęcie
              if (sciezkaZdjecia != null && sciezkaZdjecia.isNotEmpty && File(sciezkaZdjecia).existsSync()) ...[
                const SizedBox(height: 20),
                Text('Oryginalny skan', style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface,
                )),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.file(File(sciezkaZdjecia), fit: BoxFit.contain),
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}
