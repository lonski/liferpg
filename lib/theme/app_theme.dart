import 'package:flutter/material.dart';

import 'rpg_theme.dart';

export 'rpg_theme.dart';

// Achievement badge metals (AchievementBadge): each tier's ring runs
// light -> mid -> dark, and its emblem is inked on the accent disk. Metal is
// metal in every theme, so these stay constants rather than RpgTheme roles;
// gold's mid/dark and ruby's mid/dark come from the active theme.
const Color badgeGoldLight = Color(0xFFF6DC8E);
const Color badgeGoldMid = Color(0xFFC8860A);
const Color badgeGoldDark = Color(0xFF6B4405);
const Color badgeGoldEmblem = Color(0xFFF3D27A);
const Color badgeSilverLight = Color(0xFFF4F2EC);
const Color badgeSilverMid = Color(0xFFA8A398);
const Color badgeSilverDark = Color(0xFF4F4B44);
const Color badgeSilverEmblem = Color(0xFFE9E6DE);
const Color badgeBronzeLight = Color(0xFFEDB98A);
const Color badgeBronzeMid = Color(0xFFA3612B);
const Color badgeBronzeDark = Color(0xFF4A260C);
const Color badgeBronzeEmblem = Color(0xFFE8B07A);
const Color badgeRubyLight = Color(0xFFD45A48);
const Color badgeRubyMid = Color(0xFF7A1414);
const Color badgeRubyDark = Color(0xFF3A0A0A);
const Color badgeRubyEmblem = Color(0xFFF0C060);
const Color badgeDiskEdge = Color(0xFF2A0606);
const Color badgeGlow = Color(0x8CF6DC8E); // 55%
const Color badgeGlowFade = Color(0x00F6DC8E); // 0%

// Boss-fight elements (BossArena, SpellbookSheet): like the badge metals,
// fire is fire and ice is ice in every theme.
const Color spellSpark = Color(0xFFF2C46B);
const Color spellFire = Color(0xFFD9452B);
const Color spellFireCore = Color(0xFFFFF3B0);
const Color spellIce = Color(0xFF4A90C8);
const Color spellIceLight = Color(0xFF9FD3F2);
const Color spellRock = Color(0xFF7A4A2C);
const Color spellRockDark = Color(0xFF3A2210);
const Color bossHitFlash = Color(0xCCFFFFFF);

// The player's fighter on the arena (HeroPainter): character art, like the
// boss drawings, so the same in every theme.
const Color heroSkin = Color(0xFFF6C9A0);
const Color heroOutline = Color(0xFF2B1B12);
const Color heroHair = Color(0xFF6B3A1E);
const Color heroBoot = Color(0xFF4A2C1A);
const Color heroMetal = Color(0xFFC9CDD6);
const Color heroMetalDark = Color(0xFF8A93A6);
const Color heroWood = Color(0xFF8A5A2A);
const Color heroWoodDark = Color(0xFF5A3A1A);
const Color heroStraw = Color(0xFFE8C068);
const Color heroPaper = Color(0xFFFBF3E2);
const Color heroGold = Color(0xFFF2C46B);
const Color heroWizardRobe = Color(0xFF5B3A8E);
const Color heroWizardHat = Color(0xFF3E2A6B);
const Color heroBarbarianTunic = Color(0xFF8A5A36);
const Color heroFur = Color(0xFFC9A27A);
const Color heroDress = Color(0xFFC83A2A);
const Color heroApron = Color(0xFFFFF8E8);
const Color heroKnightTunic = Color(0xFF3A5A8E);
const Color heroPlume = Color(0xFFC83A2A);
const Color heroArcherTunic = Color(0xFF4E7A3A);
const Color heroHood = Color(0xFF3E6A2E);

ThemeData buildAppTheme([RpgTheme t = RpgTheme.kronika]) {
  final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
  return base.copyWith(
    extensions: [t],
    scaffoldBackgroundColor: t.bgDark,
    colorScheme: base.colorScheme.copyWith(
      primary: t.crimsonBright,
      onPrimary: t.parchmentLight,
      surface: t.parchment,
      onSurface: t.inkDark,
    ),
    textTheme: base.textTheme
        .apply(fontFamily: t.fontBody, bodyColor: t.inkDark, displayColor: t.inkDark)
        .copyWith(
          displayLarge: TextStyle(fontFamily: t.fontDisplay),
          displayMedium: TextStyle(fontFamily: t.fontDisplay),
          headlineLarge: TextStyle(fontFamily: t.fontDisplay),
          headlineMedium: TextStyle(fontFamily: t.fontDisplay),
          headlineSmall: TextStyle(fontFamily: t.fontDisplay),
          titleLarge: TextStyle(fontFamily: t.fontDisplay),
        ),
    inputDecorationTheme: InputDecorationTheme(
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.crimsonBorder),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.crimsonBright),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.crimsonDeep,
      contentTextStyle: TextStyle(fontFamily: t.fontBody, color: t.parchmentLight),
    ),
    // App-wide switch styling (not screen-specific): the old
    // activeThumbColor/activeTrackColor pairing on the user-management
    // screen set both to crimsonBright, making an ON switch a solid crimson
    // pill with the thumb invisible inside it, while the OFF state fell
    // back to Material's light-theme defaults -- a bright near-white track
    // that read as MORE prominent than "on". Every state below is spelled
    // out explicitly against the scaffold so thumb and track are always
    // distinguishable:
    //  - ON: crimsonBright track (clearly the "hot"/active colour) with a
    //    light parchmentLight thumb and a goldBorder ring -- unmistakably
    //    lit up. Thumb-vs-track contrast ~9:1 (Kronika).
    //  - OFF: a muted crimsonDeep track (recedes vs. the bright ON track)
    //    with a dimmer parchmentMuted thumb and a goldBorderFaint outline
    //    so the pill shape still reads against the scaffold. Thumb-vs-track
    //    contrast ~5.6:1 (Kronika).
    //  - Disabled: both thumb and track drop to translucent/faint tokens
    //    (ornamentInk / crimsonFaint tracks, parchmentFaint thumb) so the
    //    control reads as visibly inert, while disabled-on vs disabled-off
    //    stay distinguishable via track hue/opacity and thumb position.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return t.parchmentFaint;
        }
        return states.contains(WidgetState.selected)
            ? t.parchmentLight
            : t.parchmentMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return selected ? t.ornamentInk : t.crimsonFaint;
        }
        return selected ? t.crimsonBright : t.crimsonDeep;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return t.crimsonBorderFaint;
        }
        return states.contains(WidgetState.selected)
            ? t.goldBorder
            : t.goldBorderFaint;
      }),
    ),
  );
}
