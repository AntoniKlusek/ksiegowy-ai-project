import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import '../app_theme.dart';
import 'ekran_szczegoly_paragonu.dart';

class EkranParagonow extends StatefulWidget {
  const EkranParagonow({super.key});

  @override
  State<EkranParagonow> createState() => _EkranParagonowState();
}

class _EkranParagonowState extends State<EkranParagonow> {
  int _currentPage = 0;
  int _totalCount = 0;
  List<Map<String, dynamic>> _paragony = [];
  bool _isLoading = true;
  late StreamSubscription _dbSub;

  @override
  void initState() {
    super.initState();
    _odswiezBaze();
    _dbSub = DatabaseHelper.instance.onDatabaseChanged.listen((_) {
      if (mounted) {
        _odswiezBaze();
      }
    });
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _odswiezBaze() async {
    setState(() => _isLoading = true);
    final count = await DatabaseHelper.instance.policzParagony();
    final data = await DatabaseHelper.instance.pobierzWszystkieParagony(
      limit: 100,
      offset: _currentPage * 100,
    );
    if (mounted) {
      setState(() {
        _totalCount = count;
        _paragony = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_paragony.isEmpty && _currentPage == 0) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Brak paragonów',
        subtitle: 'Zeskanuj pierwszy paragon, aby zacząć.',
      );
    }

    final int totalPages = (_totalCount / 100).ceil();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Bottom padding moved to Column
            itemCount: _paragony.length,
            itemBuilder: (context, index) {
              final p = _paragony[index];
              return _ParagonCard(
                paragon: p,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EkranSzczegolowParagonu(paragon: p),
                  ));
                  _odswiezBaze();
                },
              );
            },
          ),
        ),
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // Bottom padding for navigation bar
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? () {
                    setState(() => _currentPage--);
                    _odswiezBaze();
                  } : null,
                ),
                Text('Strona ${_currentPage + 1} z $totalPages', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1 ? () {
                    setState(() => _currentPage++);
                    _odswiezBaze();
                  } : null,
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 120), // Spacer if no pagination needed
      ],
    );
  }
}

class _ParagonCard extends StatelessWidget {
  final Map<String, dynamic> paragon;
  final VoidCallback onTap;
  const _ParagonCard({required this.paragon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.editorialShadow,
          border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paragon['sklep'] ?? 'Nieznany sklep',
                      style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paragon['data'] ?? 'Brak daty',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '${(paragon['kwota'] as num).toStringAsFixed(2)} zł',
                style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.tertiary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.manrope(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
            )),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.outline,
            )),
          ],
        ),
      ),
    );
  }
}
