import 'package:flutter/material.dart';

/// Purple sampled from the AmarSaf mark. Used on the main button and links.
const brand = Color(0xFF6D2BD5);
const ink = Color(0xFF1C1C1E);
const canvas = Color(0xFFF6F6F8);
const fieldFill = Color(0xFFE9E9EE);
const card = Color(0xFFFFFFFF);
const clay = Color(0xFFB42318);
const line = Color(0xFFE5E5EA);
const muted = Color(0xFF6E6E73);

OutlineInputBorder _fieldBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      surface: canvas,
      onSurface: ink,
      secondary: ink,
      onSecondary: Colors.white,
      error: clay,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: canvas,
    splashFactory: InkSparkle.splashFactory,
  );

  final quietField = _fieldBorder(Colors.transparent);

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(color: ink),
    dividerColor: line,
    dividerTheme: const DividerThemeData(color: line, thickness: 0.5, space: 0.5),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ink,
      selectionColor: Color(0x331C1C1E),
      selectionHandleColor: ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: quietField,
      enabledBorder: quietField,
      focusedBorder: _fieldBorder(const Color(0xFFD1D1D6)),
      errorBorder: _fieldBorder(clay),
      focusedErrorBorder: _fieldBorder(clay),
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: brand.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(0, 44),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brand,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brand,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return ink;
          return fieldFill;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return ink;
        }),
        side: const WidgetStatePropertyAll(BorderSide.none),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: muted, textColor: ink),
  );
}
