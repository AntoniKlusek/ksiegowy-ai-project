import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'screens/ekran_skanera.dart';
import 'screens/ekran_paragonow.dart';
import 'screens/ekran_bazy.dart';
import 'screens/ekran_statystyk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const KsiegowyApp());
}

class KsiegowyApp extends StatelessWidget {
  const KsiegowyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Księgowy AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
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

  final List<Widget> _ekrany = [
    const EkranSkanera(),
    const EkranParagonow(),
    const EkranBazy(),
    const EkranStatystyk(),
  ];

  static const _navItems = [
    (icon: Icons.document_scanner_outlined, activeIcon: Icons.document_scanner, label: 'Skaner'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Paragony'),
    (icon: Icons.storage_outlined, activeIcon: Icons.storage, label: 'Baza'),
    (icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: 'Raporty'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _obecnyIndeks,
        children: _ekrany,
      ),
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryContainer],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ),
      title: Text(
        'Na co to poszło?!',
        style: GoogleFonts.manrope(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: AppColors.primary, letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, color: AppColors.primary, size: 26),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppColors.navShadow,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final bool active = i == _obecnyIndeks;
              return GestureDetector(
                onTap: () => setState(() => _obecnyIndeks = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryFixed.withOpacity(0.6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        color: active ? AppColors.primaryContainer : AppColors.outline,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: active ? AppColors.primaryContainer : AppColors.outline,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
