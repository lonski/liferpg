import 'package:flutter/material.dart';

// Palette, ported verbatim from the React theme.js and the CSS modules.
const Color crimsonDeep = Color(0xFF3A0A0A);
const Color crimson = Color(0xFF6B1A1A);
const Color crimsonBright = Color(0xFF7A1414);
const Color gold = Color(0xFFC8860A);
const Color parchment = Color(0xFFE0CCAA);
const Color parchmentLight = Color(0xFFF5E8D0);
const Color parchmentDim = Color(0xFFC8B080);
const Color inkDark = Color(0xFF1A0A0A);
const Color bgDark = Color(0xFF1A1008);

// Alpha baked into the literal; see Global Constraints.
const Color crimsonFaint = Color(0x1F6B1A1A);    // 12%
const Color crimsonBorder = Color(0x596B1A1A);   // 35%
const Color ornamentInk = Color(0x8C6B1A1A);     // 55%
const Color goldBorder = Color(0x66C8860A);      // 40%
const Color goldBorderFaint = Color(0x4DC8860A); // 30%
const Color parchmentMuted = Color(0x99F5E8D0);  // 60%
const Color parchmentFaint = Color(0x73F5E8D0);  // 45%

const LinearGradient bandGradient = LinearGradient(
  colors: [crimsonDeep, crimsonBright, crimsonDeep],
);

const LinearGradient appBarGradient = LinearGradient(
  colors: [Color(0xFF280606), Color(0xFF4A0E0E), Color(0xFF280606)],
);

const LinearGradient xpGradient = LinearGradient(colors: [crimson, gold]);

const LinearGradient buttonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [crimsonDeep, crimson],
);

const RadialGradient cardGradient = RadialGradient(
  center: Alignment(0, -1),
  radius: 1.2,
  colors: [parchmentLight, parchment, parchmentDim],
  stops: [0.0, 0.6, 1.0],
);

const String fontDisplay = 'Cinzel';
const String fontBody = 'LibreBaskerville';

ThemeData buildAppTheme() {
  final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: bgDark,
    colorScheme: base.colorScheme.copyWith(
      primary: crimsonBright,
      onPrimary: parchmentLight,
      surface: parchment,
      onSurface: inkDark,
    ),
    textTheme: base.textTheme
        .apply(fontFamily: fontBody, bodyColor: inkDark, displayColor: inkDark)
        .copyWith(
          displayLarge: const TextStyle(fontFamily: fontDisplay),
          displayMedium: const TextStyle(fontFamily: fontDisplay),
          headlineLarge: const TextStyle(fontFamily: fontDisplay),
          headlineMedium: const TextStyle(fontFamily: fontDisplay),
          headlineSmall: const TextStyle(fontFamily: fontDisplay),
          titleLarge: const TextStyle(fontFamily: fontDisplay),
        ),
    inputDecorationTheme: const InputDecorationTheme(
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: crimsonBorder),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: crimsonBright),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: crimsonDeep,
      contentTextStyle: TextStyle(fontFamily: fontBody, color: parchmentLight),
    ),
  );
}
