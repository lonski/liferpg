# Selectable themes and the Kurczaki theme

## Goal

Let each player choose how LifeRPG looks, and ship a second look — **Kurczaki**
(chickens) — alongside the original crimson/parchment **Kronika**. Approved
mockups: the "LifeRPG – motyw Kurczaki" design canvas
(https://claude.ai/artifact/2wdmFEsqncgxiiKo3AKVzz): home, login, Zadania,
the badge gallery and detail, and the "Wygląd" picker.

## Decisions

- **Depth:** full dressing — palette, fonts, ornaments and illustrations.
  Polish labels (Poziom, Złoto, Cechy, ODBIERZ…) never change with the theme.
- **Storage:** per device, SharedPreferences key `app_theme`; never Firestore.
  It must already apply on the login screen, and it is a personal preference,
  not character data. Default: Kronika.
- **Picker:** a palette icon in the home AppBar opens a bottom sheet with one
  previewed tile per theme; a tap applies, remembers and closes.
- **Architecture:** a `ThemeExtension` (`RpgTheme`) read through
  `context.rpg`, chosen over global mutable getters: idiomatic, rebuilds on
  change by itself, and testable per widget tree. The old top-level palette
  constants are gone; every use site was rewritten (analyzer-driven) to
  `context.rpg.<role>`.

## Structure

- `lib/theme/rpg_theme.dart` — `AppThemeId`, `RpgTheme` (colours by role,
  fonts, card shape tokens, `decor`), the `kronika` and `kurczaki` instances,
  `context.rpg`. Missing extension ⇒ Kronika, so bare test apps keep working.
- `lib/theme/decor.dart` — `RpgDecor` (Kronika: ✦ ❧ ⚔ ⟳ text glyphs, all
  illustration hooks null) and `KurczakiDecor`; `KurczakArt` for the SVGs in
  `assets/kurczaki/`; `eggPath` shared by every egg.
- `lib/theme/ornaments.dart` — the ornament widgets delegate their glyphs to
  `decor`; new `OrnamentedLabel`, `Perched` (an illustration on a card's top
  edge, `IgnorePointer`), `FooterSceneView`, `ThemeBackdrop`.
- `lib/data/app_theme_repository.dart`, `lib/providers/app_theme_providers.dart`
  — persistence and `appThemeProvider`.
- `lib/features/theme/theme_picker_sheet.dart` — the "Wygląd" sheet.

Text drawn straight on the scaffold uses the `onBg*` roles: Kronika's scaffold
is near-black (light text), Kurczaki's is light straw (dark text).

## Kurczaki specifics

- Palette: straw `#FCE9A8` with a dot grid, eggshell cards, comb red
  `#B83224` accents, yolk/beak highlights, brown ink `#4A2A12`; rounder cards
  (18 px) with a hard yellow ledge shadow; pill buttons.
- Illustrations: hen nesting on the character card, chick on the quests
  summary and on open board quests, hen on a live daily quest, rooster beside
  the Zadania title, hen and chicks on grass closing the home / Zadania /
  gallery lists, fence + rooster + family on the login screen, a proud hen and
  a chick beside the big badge on its detail screen.
- Card details: chick heads flank band labels, footprints in the corners,
  marching chicks in the closing band, a chick on the divider and riding the
  XP bar, a golden egg by the gold, traits with a feather and their value in a
  yolk egg (≤ 3 characters; longer legacy values stay text).
- Badges: an egg cast in the tier's metal with an accent egg inset and the
  emblem, sitting in a straw nest; the same footprint as the Kronika medal.
- Electronics: the count in an egg that fills with yolk over the day (paler
  while a claim is pending, a dashed shell once claimed), in a thin Fredoka
  Light digit filling the egg.
- Fonts: **Baloo 2** (display, subset to Latin + Latin Extended) and
  **Nunito** (body). Fredoka — used in the mockups — has no Polish diacritics,
  so it ships only in Light, for the electronics digit.

## Testing

- `test/providers/app_theme_providers_test.dart` — default, stored value,
  unknown value, `select` persists.
- `test/features/theme_picker_sheet_test.dart` — tiles, applying a theme,
  remembered choice on the first frame.
- `test/theme/kurczaki_theme_test.dart` — home, Zadania, login, gallery and
  badge screens render in Kurczaki without layout errors and with their
  illustrations; Kronika keeps its glyphs and draws none.
- Every pre-existing test runs unchanged on Kronika.
