import 'package:flutter/material.dart';

import 'decor.dart';
import 'lagotto_decor.dart';

/// The selectable looks. The persisted value is [name], so renaming a
/// constant silently resets everyone's choice to the default.
enum AppThemeId {
  kronika,
  kurczaki,
  lagotto;

  static AppThemeId fromName(String? name) => AppThemeId.values.firstWhere(
        (id) => id.name == name,
        orElse: () => AppThemeId.kronika,
      );

  RpgTheme get theme => switch (this) {
        AppThemeId.kronika => RpgTheme.kronika,
        AppThemeId.kurczaki => RpgTheme.kurczaki,
        AppThemeId.lagotto => RpgTheme.lagotto,
      };
}

/// Everything that differs between the selectable looks: colours, fonts,
/// shapes, and (through [decor]) the ornaments and illustrations.
///
/// The colour names are role names inherited from the original Kronika
/// palette (ported from the React app) -- `crimson` is "the accent ink",
/// `parchment*` "the card surface / light text on a dark band", `gold`
/// "the highlight", `bgDark` "the scaffold". Another theme fills the same
/// roles with its own hues (Kurczaki's `crimson` is a comb red, its `bgDark`
/// a light straw yellow), which is why text drawn straight on the scaffold
/// uses the `onBg*` roles rather than `parchment*`.
///
/// Read it with `context.rpg`; it lives in [ThemeData.extensions].
@immutable
class RpgTheme extends ThemeExtension<RpgTheme> {
  const RpgTheme({
    required this.id,
    required this.decor,
    required this.fontDisplay,
    required this.fontBody,
    required this.crimsonDeep,
    required this.crimson,
    required this.crimsonBright,
    required this.gold,
    required this.parchment,
    required this.parchmentLight,
    required this.parchmentDim,
    required this.inkDark,
    required this.bgDark,
    required this.inkHeading,
    required this.traitNameInk,
    required this.crimsonFaint,
    required this.crimsonBgFaint,
    required this.crimsonBorder,
    required this.crimsonBorderStrong,
    required this.crimsonBorderFaint,
    required this.ornamentInk,
    required this.goldBorder,
    required this.goldBorderFaint,
    required this.goldGlyph,
    required this.goldSubtitle,
    required this.parchmentMuted,
    required this.parchmentSoft,
    required this.parchmentFaint,
    required this.parchmentMedium,
    required this.parchmentGhost,
    required this.bandLabelColor,
    required this.onBg,
    required this.onBgMuted,
    required this.onBgFaint,
    required this.onBgGhost,
    required this.bgTint,
    required this.cardMuted,
    required this.cardShadowColor,
    required this.dialogShadowColor,
    required this.buttonShadowColor,
    required this.cardLedgeColor,
    required this.goldBandDeep,
    required this.bandGradient,
    required this.goldBandGradient,
    required this.appBarGradient,
    required this.xpGradient,
    required this.buttonGradient,
    required this.cardGradient,
    required this.cardRadius,
    required this.cardBorderWidth,
    required this.innerRadius,
    required this.buttonRadius,
    required this.tileRadius,
    required this.actionFill,
    required this.onActionFill,
    required this.actionBorder,
  });

  final AppThemeId id;

  /// Ornaments and illustrations; see [RpgDecor].
  final RpgDecor decor;

  final String fontDisplay;
  final String fontBody;

  final Color crimsonDeep;
  final Color crimson;
  final Color crimsonBright;
  final Color gold;
  final Color parchment;
  final Color parchmentLight;
  final Color parchmentDim;
  final Color inkDark;
  final Color bgDark;

  /// Headings/values painted directly on the card gradient.
  final Color inkHeading;

  /// Editor trait-name text.
  final Color traitNameInk;

  final Color crimsonFaint;
  final Color crimsonBgFaint;
  final Color crimsonBorder;
  final Color crimsonBorderStrong;
  final Color crimsonBorderFaint;
  final Color ornamentInk;
  final Color goldBorder;
  final Color goldBorderFaint;
  final Color goldGlyph;
  final Color goldSubtitle;
  final Color parchmentMuted;
  final Color parchmentSoft;
  final Color parchmentFaint;
  final Color parchmentMedium;
  final Color parchmentGhost;

  /// TopBand label text.
  final Color bandLabelColor;

  /// Text and icons drawn straight on the scaffold ([bgDark]).
  final Color onBg;
  final Color onBgMuted;
  final Color onBgFaint;
  final Color onBgGhost;

  /// A faint panel tint on the scaffold (the admin daily-quest rows).
  final Color bgTint;

  /// Recessive text on a card (a withdrawn quest's badge).
  final Color cardMuted;

  final Color cardShadowColor;
  final Color dialogShadowColor;
  final Color buttonShadowColor;

  /// A hard, unblurred ledge under cards (Kurczaki's cartoon look); null for
  /// none.
  final Color? cardLedgeColor;

  final Color goldBandDeep;
  final Gradient bandGradient;

  /// The daily-quest band -- distinct from [bandGradient] at a glance.
  final Gradient goldBandGradient;
  final Gradient appBarGradient;
  final Gradient xpGradient;
  final Gradient buttonGradient;
  final Gradient cardGradient;

  /// Outer card frame corner radius and border width.
  final double cardRadius;
  final double cardBorderWidth;

  /// The hairline frame inside a card.
  final double innerRadius;

  /// Corner radius of a primary button (Kurczaki: a pill).
  final double buttonRadius;

  /// Corner radius of a small grid tile (the badge gallery).
  final double tileRadius;

  /// A compact filled action on a card (ODBIERZ): fill, label, outline.
  final Color actionFill;
  final Color onActionFill;
  final Color actionBorder;

  /// The "Cechy" divider heading, on both the character card and the edit
  /// screen. Deliberately smaller and wider-tracked than the stat/field
  /// labels around it.
  TextStyle get traitsDividerLabel => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 12,
        letterSpacing: 3,
        color: crimson,
      );

  /// The drop shadow(s) under a framed card; [blur]/[offset] keep each
  /// call site's original softness.
  List<BoxShadow> cardShadows({double blur = 24, Offset offset = const Offset(0, 6)}) => [
        if (cardLedgeColor != null)
          BoxShadow(color: cardLedgeColor!, offset: Offset(0, offset.dy - 1)),
        BoxShadow(color: cardShadowColor, blurRadius: blur, offset: offset),
      ];

  static RpgTheme of(BuildContext context) =>
      Theme.of(context).extension<RpgTheme>() ?? kronika;

  /// The original look, ported verbatim from the React theme.js and the CSS
  /// modules.
  static const RpgTheme kronika = RpgTheme(
    id: AppThemeId.kronika,
    decor: KronikaDecor(),
    fontDisplay: 'Marcellus',
    fontBody: 'EBGaramond',
    crimsonDeep: Color(0xFF3A0A0A),
    crimson: Color(0xFF6B1A1A),
    crimsonBright: Color(0xFF7A1414),
    gold: Color(0xFFC8860A),
    parchment: Color(0xFFE0CCAA),
    parchmentLight: Color(0xFFF5E8D0),
    parchmentDim: Color(0xFFC8B080),
    inkDark: Color(0xFF1A0A0A),
    bgDark: Color(0xFF1A1008),
    inkHeading: Color(0xFF2D0A0A),
    traitNameInk: Color(0xFF3D1010),
    crimsonFaint: Color(0x1A6B1A1A), // 10%
    crimsonBgFaint: Color(0x146B1A1A), // 8%
    crimsonBorder: Color(0x596B1A1A), // 35%
    crimsonBorderStrong: Color(0x666B1A1A), // 40%
    crimsonBorderFaint: Color(0x336B1A1A), // 20%
    ornamentInk: Color(0x8C6B1A1A), // 55%
    goldBorder: Color(0x66C8860A), // 40%
    goldBorderFaint: Color(0x4DC8860A), // 30%
    goldGlyph: Color(0x80C8860A), // 50%
    goldSubtitle: Color(0xB3C8860A), // 70%
    parchmentMuted: Color(0x99F5E8D0), // 60%
    parchmentSoft: Color(0x8CF5E8D0), // 55%
    parchmentFaint: Color(0x73F5E8D0), // 45%
    parchmentMedium: Color(0x80F5E8D0), // 50%
    parchmentGhost: Color(0x33F5E8D0), // 20%
    bandLabelColor: Color(0xD9F5E8D0), // 85%
    onBg: Color(0xFFF5E8D0),
    onBgMuted: Color(0x99F5E8D0),
    onBgFaint: Color(0x73F5E8D0),
    onBgGhost: Color(0x33F5E8D0),
    bgTint: Color(0x0DF5E8D0), // ~5% parchment tint on bgDark
    cardMuted: Color(0x99F5E8D0),
    cardShadowColor: Color(0x99000000), // 60%
    dialogShadowColor: Color(0xB3000000), // 70%
    buttonShadowColor: Color(0x80000000), // 50%
    cardLedgeColor: null,
    goldBandDeep: Color(0xFF6B4405),
    bandGradient: LinearGradient(
      colors: [Color(0xFF3A0A0A), Color(0xFF7A1414), Color(0xFF3A0A0A)],
    ),
    goldBandGradient: LinearGradient(
      colors: [Color(0xFF6B4405), Color(0xFFC8860A), Color(0xFF6B4405)],
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF280606), Color(0xFF4A0E0E), Color(0xFF280606)],
    ),
    xpGradient: LinearGradient(colors: [Color(0xFF6B1A1A), Color(0xFFC8860A)]),
    buttonGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A0A0A), Color(0xFF6B1A1A)],
    ),
    cardGradient: RadialGradient(
      center: Alignment(0, -1),
      radius: 1.2,
      colors: [Color(0xFFF5E8D0), Color(0xFFE0CCAA), Color(0xFFC8B080)],
      stops: [0.0, 0.6, 1.0],
    ),
    cardRadius: 4,
    cardBorderWidth: 2,
    innerRadius: 2,
    buttonRadius: 3,
    tileRadius: 4,
    actionFill: Color(0xFF6B1A1A),
    onActionFill: Color(0xFFF5E8D0),
    actionBorder: Color(0x80C8860A),
  );

  /// Straw, eggshell, comb red and yolk -- see the "motyw Kurczaki"
  /// mockups referenced from the design doc.
  static const RpgTheme kurczaki = RpgTheme(
    id: AppThemeId.kurczaki,
    decor: KurczakiDecor(),
    fontDisplay: 'Baloo2',
    fontBody: 'Nunito',
    crimsonDeep: Color(0xFF8E2117),
    crimson: Color(0xFFB83224),
    crimsonBright: Color(0xFFD23E2C),
    gold: Color(0xFFEE8A1E),
    parchment: Color(0xFFFFF3D9),
    parchmentLight: Color(0xFFFFFDF6),
    parchmentDim: Color(0xFFF6DFAE),
    inkDark: Color(0xFF3A2210),
    bgDark: Color(0xFFFCE9A8),
    inkHeading: Color(0xFF4A2A12),
    traitNameInk: Color(0xFF6B3A1A),
    crimsonFaint: Color(0x1AB83224),
    crimsonBgFaint: Color(0x14B83224),
    crimsonBorder: Color(0x59B83224),
    crimsonBorderStrong: Color(0x73B83224),
    crimsonBorderFaint: Color(0x33B83224),
    ornamentInk: Color(0x8CB83224),
    goldBorder: Color(0xB3FFC83D),
    goldBorderFaint: Color(0x80FFC83D),
    goldGlyph: Color(0xCCFFC83D),
    goldSubtitle: Color(0xFF8E2117),
    parchmentMuted: Color(0xB3FFF5DC),
    parchmentSoft: Color(0xA6FFF5DC),
    parchmentFaint: Color(0x8CFFF5DC),
    parchmentMedium: Color(0x99FFF5DC),
    parchmentGhost: Color(0x4DFFF5DC),
    bandLabelColor: Color(0xFFFFF5DC),
    onBg: Color(0xFF4A2A12),
    onBgMuted: Color(0xD94A2A12),
    onBgFaint: Color(0xA64A2A12),
    onBgGhost: Color(0x8C4A2A12),
    bgTint: Color(0x99FFFDF6),
    cardMuted: Color(0xFF8A6A4A),
    cardShadowColor: Color(0x404A2A12),
    dialogShadowColor: Color(0x664A2A12),
    buttonShadowColor: Color(0x4D4A2A12),
    cardLedgeColor: Color(0xFFD9A63A),
    goldBandDeep: Color(0xFFEE8A1E),
    bandGradient: LinearGradient(
      colors: [Color(0xFF8E2117), Color(0xFFC83A2A), Color(0xFF8E2117)],
    ),
    goldBandGradient: LinearGradient(
      colors: [Color(0xFFEE8A1E), Color(0xFFFFD95A), Color(0xFFEE8A1E)],
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFFA8261A), Color(0xFFD23E2C), Color(0xFFA8261A)],
    ),
    xpGradient: LinearGradient(colors: [Color(0xFFFFD95A), Color(0xFFEE8A1E)]),
    buttonGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA8261A), Color(0xFFC83A2A)],
    ),
    cardGradient: RadialGradient(
      center: Alignment(0, -1),
      radius: 1.2,
      colors: [Color(0xFFFFFDF6), Color(0xFFFFF3D9), Color(0xFFF6DFAE)],
      stops: [0.0, 0.6, 1.0],
    ),
    cardRadius: 18,
    cardBorderWidth: 3,
    innerRadius: 12,
    buttonRadius: 999,
    tileRadius: 14,
    actionFill: Color(0xFFFFC83D),
    onActionFill: Color(0xFF4A2A12),
    actionBorder: Color(0xFFB83224),
  );

  /// Curly Lagotto Romagnolo dogs hunting truffles in an oak wood: honey
  /// gold, chocolate leather, arancio and cream -- see the "motyw Lagotto"
  /// mockups referenced from its design doc.
  static const RpgTheme lagotto = RpgTheme(
    id: AppThemeId.lagotto,
    decor: LagottoDecor(),
    fontDisplay: 'Fraunces',
    fontBody: 'Nunito',
    crimsonDeep: Color(0xFF4A2C1A),
    crimson: Color(0xFF6B4128),
    crimsonBright: Color(0xFF8A5634),
    gold: Color(0xFFE08A3C),
    parchment: Color(0xFFF8EEDC),
    parchmentLight: Color(0xFFFFFBF3),
    parchmentDim: Color(0xFFECDABB),
    inkDark: Color(0xFF3B2A20),
    bgDark: Color(0xFFF2D58A),
    inkHeading: Color(0xFF3B2A20),
    traitNameInk: Color(0xFF6B4A35),
    crimsonFaint: Color(0x1A6B4128),
    crimsonBgFaint: Color(0x146B4128),
    crimsonBorder: Color(0x596B4128),
    crimsonBorderStrong: Color(0x736B4128),
    crimsonBorderFaint: Color(0x336B4128),
    ornamentInk: Color(0x8C6B4128),
    goldBorder: Color(0xB3F3B866),
    goldBorderFaint: Color(0x80F3B866),
    goldGlyph: Color(0xCCF3B866),
    goldSubtitle: Color(0xFF4A2C1A),
    parchmentMuted: Color(0xB3FFF3E0),
    parchmentSoft: Color(0xA6FFF3E0),
    parchmentFaint: Color(0x8CFFF3E0),
    parchmentMedium: Color(0x99FFF3E0),
    parchmentGhost: Color(0x4DFFF3E0),
    bandLabelColor: Color(0xFFFFF3E0),
    onBg: Color(0xFF3B2A20),
    onBgMuted: Color(0xD93B2A20),
    onBgFaint: Color(0xA63B2A20),
    onBgGhost: Color(0x8C3B2A20),
    bgTint: Color(0x99FFFBF3),
    cardMuted: Color(0xFF8A6A50),
    cardShadowColor: Color(0x403B2A20),
    dialogShadowColor: Color(0x663B2A20),
    buttonShadowColor: Color(0x4D3B2A20),
    cardLedgeColor: Color(0xFFC49A45),
    goldBandDeep: Color(0xFFC86F2A),
    bandGradient: LinearGradient(
      colors: [Color(0xFF4A2C1A), Color(0xFF7A4A2C), Color(0xFF4A2C1A)],
    ),
    goldBandGradient: LinearGradient(
      colors: [Color(0xFFC86F2A), Color(0xFFF0A55A), Color(0xFFC86F2A)],
    ),
    appBarGradient: LinearGradient(
      colors: [Color(0xFF3F2516), Color(0xFF6B4128), Color(0xFF3F2516)],
    ),
    xpGradient: LinearGradient(colors: [Color(0xFFF3B866), Color(0xFFE08A3C)]),
    buttonGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4A2C1A), Color(0xFF7A4A2C)],
    ),
    cardGradient: RadialGradient(
      center: Alignment(0, -1),
      radius: 1.2,
      colors: [Color(0xFFFFFBF3), Color(0xFFF8EEDC), Color(0xFFECDABB)],
      stops: [0.0, 0.6, 1.0],
    ),
    cardRadius: 20,
    cardBorderWidth: 2.5,
    innerRadius: 14,
    buttonRadius: 12,
    tileRadius: 16,
    actionFill: Color(0xFFE08A3C),
    onActionFill: Color(0xFF3B2A20),
    actionBorder: Color(0xFF6B4128),
  );

  @override
  RpgTheme copyWith() => this;

  /// Themes switch outright -- a half-chicken interpolation has no meaning.
  @override
  RpgTheme lerp(covariant RpgTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension RpgThemeContext on BuildContext {
  RpgTheme get rpg => RpgTheme.of(this);
}
