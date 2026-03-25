import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import '../app_theme.dart';

class EkranStatystyk extends StatelessWidget {
  const EkranStatystyk({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: DatabaseHelper.instance.onDatabaseChanged,
      builder: (context, snapshotStream) {
        return FutureBuilder(
          future: Future.wait([
            DatabaseHelper.instance.pobierzWszystkieParagony(),
            DatabaseHelper.instance.pobierzWszystkiePozycje(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (!snapshot.hasData || (snapshot.data ?? []).isEmpty || (snapshot.data![0] as List).isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 64, color: AppColors.outlineVariant),
                    const SizedBox(height: 16),
                    Text('Brak danych', style: GoogleFonts.manrope(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                    )),
                    const SizedBox(height: 6),
                    Text('Zeskanuj paragony, aby zobaczyć raporty.', style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.outline,
                    )),
                  ],
                ),
              );
            }

            final data = snapshot.data ?? [[], []];
            final paragony = (data.isNotEmpty ? data[0] : []) as List<Map<String, dynamic>>;
            final pozycje = (data.length > 1 ? data[1] : []) as List<Map<String, dynamic>>;

            // Calculations
            double sumaCalkowita = paragony.fold(0, (sum, p) => sum + (p['kwota'] as num));
            double sredniParagon = paragony.isNotEmpty ? sumaCalkowita / paragony.length : 0;

            Map<String, dynamic>? najdrozszyProdukt = pozycje.isNotEmpty
                ? pozycje.reduce((a, b) => (a['cena'] as num) > (b['cena'] as num) ? a : b)
                : null;

            Map<String, int> czestotliwosc = {};
            for (var p in pozycje) {
              String nazwa = p['nazwa'] ?? 'Nieznany';
              czestotliwosc[nazwa] = (czestotliwosc[nazwa] ?? 0) + 1;
            }
            String najczestszyNazwa = 'Brak';
            int najczestszyIle = 0;
            if (czestotliwosc.isNotEmpty) {
              var sorted = czestotliwosc.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              najczestszyNazwa = sorted.first.key;
              najczestszyIle = sorted.first.value;
            }

            Map<String, double> sklepyWydatki = {};
            for (var p in paragony) {
              String sklep = p['sklep'] ?? 'Inne';
              sklepyWydatki[sklep] = (sklepyWydatki[sklep] ?? 0) + (p['kwota'] as num);
            }
            var topSklepy = sklepyWydatki.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final top5 = topSklepy.take(5).toList();
            final maxWydatek = top5.isNotEmpty ? top5.first.value : 1.0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                // ── Hero card: łączne wydatki
                _HeroCard(suma: sumaCalkowita, ileParagona: paragony.length),
                const SizedBox(height: 20),

                // ── Analytics grid: top sklepy + donut
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TopSklepyCard(topSklepy: top5, maxWydatek: maxWydatek)),
                    const SizedBox(width: 12),
                    Expanded(child: _SpendingMixCard(topSklepy: top5, max: maxWydatek)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 4 mini-widgety
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.55,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MiniWidget(
                      icon: Icons.payments_outlined,
                      label: 'Najdroższy produkt',
                      value: najdrozszyProdukt != null ? najdrozszyProdukt['nazwa'] ?? 'Brak' : 'Brak',
                      amount: najdrozszyProdukt != null ? '${(najdrozszyProdukt['cena'] as num).toStringAsFixed(2)} zł' : '–',
                      accentColor: AppColors.primary,
                      amountColor: AppColors.tertiary,
                    ),
                    _MiniWidget(
                      icon: Icons.shopping_cart_outlined,
                      label: 'Najczęstszy produkt',
                      value: najczestszyNazwa,
                      amount: najczestszyIle > 0 ? '$najczestszyIle razy' : '–',
                      accentColor: AppColors.primaryContainer,
                      amountColor: AppColors.onSurfaceVariant,
                    ),
                    _MiniWidget(
                      icon: Icons.receipt_long_outlined,
                      label: 'Średni paragon',
                      value: '${paragony.length} transakcji',
                      amount: '${sredniParagon.toStringAsFixed(2)} zł',
                      accentColor: AppColors.secondary,
                      amountColor: AppColors.tertiary,
                    ),
                    _MiniWidget(
                      icon: Icons.verified_outlined,
                      label: 'Łączne paragony',
                      value: 'Kolekcja',
                      amount: '${paragony.length} szt.',
                      accentColor: AppColors.tertiary,
                      amountColor: AppColors.tertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── AI Insight banner
                _AIInsightBanner(sumaCalkowita: sumaCalkowita),
              ],
            );
          },
        );
      }
    );
  }
}

// ── Hero card
class _HeroCard extends StatelessWidget {
  final double suma;
  final int ileParagona;
  const _HeroCard({required this.suma, required this.ileParagona});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.editorialShadow,
      ),
      child: Stack(
        children: [
          // Background glow decoration
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ŁĄCZNE WYDATKI',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    suma.toStringAsFixed(2),
                    style: GoogleFonts.manrope(
                      fontSize: 48, fontWeight: FontWeight.w800,
                      color: AppColors.tertiary, height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('PLN', style: GoogleFonts.manrope(
                      fontSize: 18, fontWeight: FontWeight.w500,
                      color: AppColors.tertiary.withOpacity(0.6),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 14, color: AppColors.tertiary),
                    const SizedBox(width: 5),
                    Text('$ileParagona paragonów', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.tertiary,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top sklepy (bar chart)
class _TopSklepyCard extends StatelessWidget {
  final List<MapEntry<String, double>> topSklepy;
  final double maxWydatek;
  const _TopSklepyCard({required this.topSklepy, required this.maxWydatek});

  static const _barColors = [
    AppColors.primary,
    AppColors.primaryContainer,
    AppColors.secondary,
    Color(0xFF6B7FC4),
    Color(0xFF9BAEE0),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Sklepy', style: GoogleFonts.manrope(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface,
          )),
          const SizedBox(height: 16),
          ...List.generate(topSklepy.length, (i) {
            final e = topSklepy[i];
            final pct = maxWydatek > 0 ? e.value / maxWydatek : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value.toStringAsFixed(0)} zł',
                        style: GoogleFonts.manrope(
                          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (ctx, constraints) => Stack(
                      children: [
                        Container(
                          height: 6, width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 6,
                          width: constraints.maxWidth * pct,
                          decoration: BoxDecoration(
                            color: _barColors[i % _barColors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Spending Mix (donut)
class _SpendingMixCard extends StatelessWidget {
  final List<MapEntry<String, double>> topSklepy;
  final double max;
  const _SpendingMixCard({required this.topSklepy, required this.max});

  @override
  Widget build(BuildContext context) {
    double total = topSklepy.fold(0.0, (s, e) => s + e.value);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Udział', style: GoogleFonts.manrope(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface,
          )),
          Text('wg sklepu', style: GoogleFonts.inter(
            fontSize: 11, color: AppColors.onSurfaceVariant,
          )),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 100, height: 100,
              child: CustomPaint(
                painter: _DonutPainter(
                  values: topSklepy.map((e) => e.value).toList(),
                  total: total > 0 ? total : 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(min(3, topSklepy.length), (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _DonutPainter._colors[i % _DonutPainter._colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      topSklepy[i].key,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(topSklepy[i].value / (total > 0 ? total : 1.0) * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final double total;
  static const _colors = [
    AppColors.primary,          // Navy
    AppColors.tertiary,         // Green
    Color(0xFFE5B05C),          // Gold
    Color(0xFF7D5260),          // Plum/Burgundy
    Color(0xFF4FA095),          // Teal/Aqua
  ];

  _DonutPainter({required this.values, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2);
    const stroke = 22.0;
    double startAngle = -pi / 2;

    if (values.isEmpty) {
      final paint = Paint()
        ..color = AppColors.surfaceContainerHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawOval(rect, paint);
      return;
    }

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = _colors[i % _colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: rect.center, radius: size.width / 2 - stroke / 2), startAngle, sweep - 0.05, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Mini widget (4 summary cards)
class _MiniWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String amount;
  final Color accentColor;
  final Color amountColor;
  const _MiniWidget({
    required this.icon, required this.label, required this.value,
    required this.amount, required this.accentColor, required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant, letterSpacing: 0.8),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.manrope(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface,
          ), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(amount, style: GoogleFonts.manrope(
            fontSize: 13, fontWeight: FontWeight.w700, color: amountColor,
          )),
        ],
      ),
    );
  }
}

// ── AI Insight banner
class _AIInsightBanner extends StatelessWidget {
  final double sumaCalkowita;
  const _AIInsightBanner({required this.sumaCalkowita});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analiza AI', style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                )),
                const SizedBox(height: 4),
                Text(
                  sumaCalkowita > 0
                      ? 'Masz ${sumaCalkowita.toStringAsFixed(2)} zł wydatków. Sprawdź, gdzie możesz zaoszczędzić!'
                      : 'Zeskanuj paragony, by uzyskać analizę AI swoich wydatków.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.primaryFixed, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
