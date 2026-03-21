import 'package:flutter/material.dart';

/// App theme — Material 3, dark-mode-first, minimal/zen aesthetic.
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.blueGrey,
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.blueGrey,
  );
}
