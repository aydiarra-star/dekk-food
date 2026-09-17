import 'package:flutter/material.dart';

class DekkColors {
  DekkColors._();

  static const Color orange = Color(0xFFF4511E);
  static const Color warmOrange = Color(0xFFFF6B35);
  static const Color cream = Color(0xFFFFF7F2);
  static const Color cardGrey = Color(0xFFF1F3F5);
  static const Color success = Color(0xFF16803C);
}

ThemeData buildDekkTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: DekkColors.orange,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF171411) : const Color(0xFFF7F7F8),
    appBarTheme: AppBarTheme(
      backgroundColor: DekkColors.orange,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF211A17) : Colors.white,
      indicatorColor: DekkColors.orange.withOpacity(0.16),
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(MaterialState.selected)
              ? DekkColors.orange
              : (isDark ? Colors.white70 : Colors.black54),
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected)
              ? DekkColors.orange
              : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF28211E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE6E8EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DekkColors.orange, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white12 : const Color(0xFFE6E8EB),
    ),
  );
}
