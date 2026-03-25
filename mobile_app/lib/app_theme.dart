import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary — kobalt / granat
  static const primary = Color(0xFF00327D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF0047AB);
  static const onPrimaryContainer = Color(0xFFA5BDFF);
  static const primaryFixed = Color(0xFFDAE2FF);
  static const primaryFixedDim = Color(0xFFB1C5FF);

  // Secondary — ciemny niebieski-szary
  static const secondary = Color(0xFF4E5E85);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFC1D1FF);
  static const onSecondaryContainer = Color(0xFF4A5980);

  // Tertiary — zieleń (zysk / oszczędności)
  static const tertiary = Color(0xFF00400C);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF005A14);
  static const tertiaryFixed = Color(0xFFA3F69C);

  // Surface / Background
  static const surface = Color(0xFFF6FAFF);
  static const surfaceBright = Color(0xFFF6FAFF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF0F4FA);
  static const surfaceContainer = Color(0xFFEAEEF4);
  static const surfaceContainerHigh = Color(0xFFE4E8EE);
  static const surfaceContainerHighest = Color(0xFFDFE3E9);
  static const surfaceDim = Color(0xFFD6DAE0);
  static const surfaceVariant = Color(0xFFDFE3E9);
  static const background = Color(0xFFF6FAFF);

  // On-Surface
  static const onSurface = Color(0xFF171C20);
  static const onSurfaceVariant = Color(0xFF434653);
  static const onBackground = Color(0xFF171C20);

  // Outline
  static const outline = Color(0xFF737784);
  static const outlineVariant = Color(0xFFC3C6D5);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);

  // Gradient dla przycisków
  static const Gradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  // Cień editorial (lekki niebieski)
  static List<BoxShadow> editorialShadow = [
    BoxShadow(
      color: Color(0xFF00327D).withOpacity(0.08),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  // Cień dla BottomNav
  static List<BoxShadow> navShadow = [
    BoxShadow(
      color: Color(0xFF00327D).withOpacity(0.06),
      blurRadius: 32,
      offset: Offset(0, -12),
    ),
  ];
}

class AppTextStyles {
  // Headline — Manrope (bold / extrabold)
  static TextStyle headline1(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 56, fontWeight: FontWeight.w800, color: AppColors.tertiary, height: 1.0);

  static TextStyle headline2(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface);

  static TextStyle headline3(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface);

  static TextStyle appBarTitle(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: -0.3);

  // Body / Label — Inter
  static TextStyle bodyLarge(BuildContext context) =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onSurface);

  static TextStyle bodyMedium(BuildContext context) =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurface);

  static TextStyle labelSmall(BuildContext context) =>
      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 1.2);

  static TextStyle labelMedium(BuildContext context) =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.5);

  static TextStyle amountLarge(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 42, fontWeight: FontWeight.w700, color: AppColors.tertiary, height: 1.0);

  static TextStyle amountMedium(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.tertiary);

  static TextStyle storeCard(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface);

  static TextStyle priceGreen(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.tertiary);

  static TextStyle pricePrimary(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryContainer);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.tertiaryFixed,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: Color(0xFF93000A),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF2C3135),
      onInverseSurface: Color(0xFFEDF1F7),
      inversePrimary: AppColors.primaryFixedDim,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
    ),
  );
}
