import 'package:flutter/material.dart';

/// Mars Engineers letterhead red.
const kBrandRed = Color(0xFFC62828);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandRed,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  ).copyWith(
    primary: kBrandRed,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFCE4E4),
    onPrimaryContainer: const Color(0xFF7A1010),
    secondaryContainer: const Color(0xFFFCE4E4),
    onSecondaryContainer: kBrandRed,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}
