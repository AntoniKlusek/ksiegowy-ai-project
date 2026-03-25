import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';
import '../app_theme.dart';
import 'ekran_szczegoly_paragonu.dart';

class EkranBazy extends StatefulWidget {
  const EkranBazy({super.key});

  @override
  State<EkranBazy> createState() => _EkranBazyState();
}

class _EkranBazyState extends State<EkranBazy> {
  int _currentPage = 0;
  int _totalCount = 0;
  List<Map<String, dynamic>> _pozycje = [];
  bool _isLoading = true;
  String _sortowanie = 'data_desc';
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
    final count = await DatabaseHelper.instance.policzPozycje();
    final data = await DatabaseHelper.instance.pobierzWszystkiePozycje(
      limit: 100,
      offset: _currentPage * 100,
    );
    
    var lista = List<Map<String, dynamic>>.from(data);
    if (_sortowanie == 'cena_desc') {
      lista.sort((a, b) => (b['cena'] as num).compareTo(a['cena'] as num));
    } else if (_sortowanie == 'cena_asc') {
      lista.sort((a, b) => (a['cena'] as num).compareTo(b['cena'] as num));
    } else if (_sortowanie == 'nazwa_asc') {
      lista.sort((a, b) => (a['nazwa'] ?? '').toString().compareTo((b['nazwa'] ?? '').toString()));
    } else {
      lista.sort((a, b) => (b['data'] ?? '').toString().compareTo((a['data'] ?? '').toString()));
    }

    if (mounted) {
      setState(() {
        _totalCount = count;
        _pozycje = lista;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sort bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceContainerLowest,
          child: Row(
            children: [
              Text('Sortuj:', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant,
              )),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SortChip(label: 'Najnowsze', value: 'data_desc', current: _sortowanie,
                        onTap: () { setState(() { _sortowanie = 'data_desc'; _odswiezBaze(); }); }),
                      _SortChip(label: 'Najdroższe', value: 'cena_desc', current: _sortowanie,
                        onTap: () { setState(() { _sortowanie = 'cena_desc'; _odswiezBaze(); }); }),
                      _SortChip(label: 'Najtańsze', value: 'cena_asc', current: _sortowanie,
                        onTap: () { setState(() { _sortowanie = 'cena_asc'; _odswiezBaze(); }); }),
                      _SortChip(label: 'A–Z', value: 'nazwa_asc', current: _sortowanie,
                        onTap: () { setState(() { _sortowanie = 'nazwa_asc'; _odswiezBaze(); }); }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // ── Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : (_pozycje.isEmpty && _currentPage == 0)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storage, size: 64, color: AppColors.outlineVariant),
                            const SizedBox(height: 16),
                            Text('Twoja baza jest pusta', style: GoogleFonts.manrope(
                              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant,
                            )),
                            const SizedBox(height: 6),
                            Text('Zeskanuj pierwszy paragon!', style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.outline,
                            )),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _pozycje.length,
                            itemBuilder: (context, index) {
                              final p = _pozycje[index];
                              return _PozycjaCard(
                                pozycja: p,
                                onTap: () async {
                                  // Przejdź do konkretnego paragonu
                                  final pParagon = await DatabaseHelper.instance.pobierzPojedynczyParagon(p['paragon_id']);
                                  if (pParagon != null && context.mounted) {
                                    await Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => EkranSzczegolowParagonu(paragon: pParagon),
                                    ));
                                    _odswiezBaze();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        if (_totalCount > 100)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
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
                                Text('Strona ${_currentPage + 1} z ${(_totalCount / 100).ceil()}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _currentPage < (_totalCount / 100).ceil() - 1 ? () {
                                    setState(() => _currentPage++);
                                    _odswiezBaze();
                                  } : null,
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 120),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool active = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.onSurfaceVariant,
        )),
      ),
    );
  }
}

class _PozycjaCard extends StatelessWidget {
  final Map<String, dynamic> pozycja;
  final VoidCallback onTap;
  const _PozycjaCard({required this.pozycja, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.editorialShadow,
          border: Border(left: BorderSide(color: AppColors.secondaryContainer, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pozycja['nazwa'] ?? 'Nieznany produkt',
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${pozycja['sklep'] ?? ''} • ${pozycja['data'] ?? ''}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '${(pozycja['cena'] as num).toStringAsFixed(2)} zł',
              style: GoogleFonts.manrope(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
