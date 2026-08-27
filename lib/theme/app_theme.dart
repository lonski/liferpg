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

// A darker ink than inkDark, used for headings/values painted directly on
// the parchment gradient (character name, gold value, level badge, etc.).
// Distinct from inkDark -- see CLAUDE.md fidelity notes.
const Color inkHeading = Color(0xFF2D0A0A);

// Editor trait-name text (#3d1010) -- darker than crimson, lighter than
// inkHeading; distinct from both.
const Color traitNameInk = Color(0xFF3D1010);

// Alpha baked into the literal; see Global Constraints.
const Color crimsonFaint = Color(0x1A6B1A1A);    // 10%
const Color crimsonBgFaint = Color(0x146B1A1A);  // 8%
const Color crimsonBorder = Color(0x596B1A1A);   // 35%
const Color crimsonBorderStrong = Color(0x666B1A1A); // 40%
const Color crimsonBorderFaint = Color(0x336B1A1A);  // 20%
const Color ornamentInk = Color(0x8C6B1A1A);     // 55%
const Color goldBorder = Color(0x66C8860A);      // 40%
const Color goldBorderFaint = Color(0x4DC8860A); // 30%
const Color goldGlyph = Color(0x80C8860A);       // 50%
const Color goldSubtitle = Color(0xB3C8860A);    // 70%
const Color parchmentMuted = Color(0x99F5E8D0);  // 60%
const Color parchmentSoft = Color(0x8CF5E8D0);   // 55%
const Color parchmentFaint = Color(0x73F5E8D0);  // 45%
const Color parchmentMedium = Color(0x80F5E8D0); // 50%
const Color parchmentGhost = Color(0x33F5E8D0);  // 20%
const Color bandLabelColor = Color(0xD9F5E8D0);  // 85% -- TopBand label text

// Box/text-shadow colours, named for where they're cast rather than value,
// since several unrelated shadows happen to share an alpha.
const Color cardShadowColor = Color(0x99000000);   // 60% -- card/app bar
const Color dialogShadowColor = Color(0xB3000000); // 70% -- edit/user dialogs
const Color buttonShadowColor = Color(0x80000000); // 50% -- login button

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

// Shared text roles.

// .traitsDividerLabel -- the "Cechy" divider heading, on both the character
// card and the edit screen. Deliberately smaller and wider-tracked than the
// stat/field labels around it.
const TextStyle traitsDividerLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 8,
  letterSpacing: 3,
  color: crimson,
);

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
    // App-wide switch styling (not screen-specific): the old
    // activeThumbColor/activeTrackColor pairing on the user-management
    // screen set both to crimsonBright, making an ON switch a solid crimson
    // pill with the thumb invisible inside it, while the OFF state fell
    // back to Material's light-theme defaults -- a bright near-white track
    // that read as MORE prominent than "on". Every state below is spelled
    // out explicitly against this dark (bgDark) scaffold so thumb and
    // track are always distinguishable:
    //  - ON: crimsonBright track (clearly the "hot"/active colour) with a
    //    light parchmentLight thumb and a goldBorder ring -- unmistakably
    //    lit up. Thumb-vs-track contrast ~9:1.
    //  - OFF: a muted crimsonDeep track (recedes vs. the bright ON track)
    //    with a dimmer parchmentMuted thumb and a goldBorderFaint outline
    //    so the pill shape still reads against bgDark. Thumb-vs-track
    //    contrast ~5.6:1.
    //  - Disabled: both thumb and track drop to translucent/faint tokens
    //    (ornamentInk / crimsonFaint tracks, parchmentFaint thumb) so the
    //    control reads as visibly inert, while disabled-on vs disabled-off
    //    stay distinguishable via track hue/opacity and thumb position.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return parchmentFaint;
        }
        return states.contains(WidgetState.selected)
            ? parchmentLight
            : parchmentMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return selected ? ornamentInk : crimsonFaint;
        }
        return selected ? crimsonBright : crimsonDeep;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return crimsonBorderFaint;
        }
        return states.contains(WidgetState.selected)
            ? goldBorder
            : goldBorderFaint;
      }),
    ),
  );
}
