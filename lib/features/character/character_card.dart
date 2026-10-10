import 'package:flutter/material.dart';

import '../../feature_flags.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'edit_character_screen.dart';

TextStyle _statLabel(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontDisplay,
  fontSize: 10,
  letterSpacing: 2,
  color: context.rpg.crimson,
);

// .xpMeta -- the "Doświadczenie" label and the "n / n XP" counter share this
// style; neither is uppercase and neither uses the display font.
TextStyle _xpMetaText(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontBody,
  fontSize: 10,
  fontStyle: FontStyle.italic,
  color: context.rpg.crimson,
);

class CharacterCard extends StatefulWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.canEdit,
    this.electronics,
    this.achievements,
  });

  final Character character;
  final bool canEdit;

  /// The "Dni elektroniki" section, built by the home screen (it needs
  /// providers this widget deliberately doesn't).
  final Widget? electronics;

  /// The "Odznaki" section, built by the home screen (it needs providers
  /// this widget deliberately doesn't). Null hides it.
  final Widget? achievements;

  @override
  State<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<CharacterCard> {
  bool _hintVisible = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;

    return Perched(
      spot: PerchSpot.characterCard,
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rpg.cardRadius),
        boxShadow: context.rpg.cardShadows(blur: 24, offset: const Offset(0, 6)),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: context.rpg.crimson, width: context.rpg.cardBorderWidth),
        borderRadius: BorderRadius.circular(context.rpg.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopBand(
            label: 'Karta Postaci',
            ornament: BandOrnament.star,
            trailing: widget.canEdit
                ? IconButton(
                    key: const Key('edit-character'),
                    tooltip: 'Edytuj postać',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 16,
                    color: context.rpg.parchmentSoft,
                    icon: const Icon(Icons.edit),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditCharacterScreen(character: c),
                      ),
                    ),
                  )
                : null,
          ),
          Container(
            decoration: BoxDecoration(gradient: context.rpg.cardGradient),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.rpg.crimsonBorder),
                    borderRadius: BorderRadius.circular(context.rpg.innerRadius),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NameBlock(character: c),
                      const SizedBox(height: 10),
                      const OrnamentDivider(),
                      const SizedBox(height: 10),
                      if (c.level != null) ...[
                        _LevelRow(level: c.level!),
                        const SizedBox(height: 10),
                        _XpSection(
                          character: c,
                          hintVisible: _hintVisible,
                          onToggle: () =>
                              setState(() => _hintVisible = !_hintVisible),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (c.gold != null) _GoldRow(character: c),
                      if (widget.electronics != null) ...[
                        const SizedBox(height: 14),
                        widget.electronics!,
                      ],
                      if (kShowFavour) ...[
                        const SizedBox(height: 8),
                        Text(
                          favourEmoji(c.favour),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                      if (c.traits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const LabelledDivider(label: 'Cechy'),
                        const SizedBox(height: 8),
                        _TraitPills(traits: c.traits),
                      ],
                      if (widget.achievements != null) ...[
                        const SizedBox(height: 12),
                        widget.achievements!,
                      ],
                    ],
                  ),
                ),
                const Positioned(top: 5, left: 5, child: CornerOrnament()),
                const Positioned(
                  top: 5,
                  right: 5,
                  child: CornerOrnament(mirrored: true),
                ),
              ],
            ),
          ),
          const BottomBand(),
        ],
      ),
      ),
    );
  }
}

/// Mood glyph, matching the React FavourEmoji thresholds exactly.
///
/// Deliberately public despite having no other in-app caller: `kShowFavour`
/// is a compile-time constant that is false in tests, so the glyph is never
/// rendered there and the mapping can only be covered by calling it directly.
String favourEmoji(int favour) {
  if (favour < -1) return '😠';
  if (favour == -1) return '😕';
  if (favour > 0) return '😊';
  return '😐';
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            character.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: context.rpg.fontDisplay,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: context.rpg.inkHeading,
            ),
          ),
          if (character.clazz != null)
            Text(
              character.clazz!.toUpperCase(),
              style: TextStyle(
                fontFamily: context.rpg.fontDisplay,
                fontSize: 9,
                letterSpacing: 4,
                color: context.rpg.crimson,
              ),
            ),
        ],
      );
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Poziom'.toUpperCase(), style: _statLabel(context)),
          Container(
            decoration: BoxDecoration(
              color: context.rpg.crimsonFaint,
              border: Border.all(color: context.rpg.crimsonBorderStrong),
              borderRadius: BorderRadius.circular(context.rpg.buttonRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: context.rpg.fontDisplay,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.rpg.inkHeading,
              ),
            ),
          ),
        ],
      );
}

class _XpSection extends StatelessWidget {
  const _XpSection({
    required this.character,
    required this.hintVisible,
    required this.onToggle,
  });

  final Character character;
  final bool hintVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Doświadczenie', style: _xpMetaText(context)),
              Text(
                '${character.currentXp} / ${character.nextLevelXp} XP',
                style: _xpMetaText(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            key: const Key('xp-bar'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: LayoutBuilder(builder: (context, box) {
              // Kurczaki: a chick runs along a thicker, rounder yolk bar.
              final runner = context.rpg.decor.xpRunner(context);
              final bar = Container(
                width: double.infinity,
                height: runner == null ? 8 : 12,
                decoration: BoxDecoration(
                  color: context.rpg.crimsonFaint,
                  border: Border.all(color: context.rpg.crimsonBorder),
                  borderRadius: BorderRadius.circular(runner == null ? 2 : 6),
                ),
                clipBehavior: Clip.antiAlias,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: character.xpFraction,
                  child: DecoratedBox(
                    key: const Key('xp-fill'),
                    decoration: BoxDecoration(gradient: context.rpg.xpGradient),
                  ),
                ),
              );
              if (runner == null) return bar;
              final left = (box.maxWidth * character.xpFraction - 16)
                  .clamp(-6.0, box.maxWidth - 24);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  bar,
                  Positioned(left: left, top: -19, child: IgnorePointer(child: runner)),
                ],
              );
            }),
          ),
          // React shows/hides this hint with no transition; no AnimatedSize.
          if (hintVisible)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: context.rpg.crimsonBgFaint,
                  border: Border.all(color: context.rpg.crimsonBorderFaint),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Text(
                  'Do następnego poziomu: ${character.xpRemaining} XP',
                  style: TextStyle(
                    fontFamily: context.rpg.fontBody,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: context.rpg.crimson,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _GoldRow extends StatelessWidget {
  const _GoldRow({required this.character});

  static TextStyle _goldValue(BuildContext context) => TextStyle(
    fontFamily: context.rpg.fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: context.rpg.inkHeading,
  );

  final Character character;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Złoto'.toUpperCase(), style: _statLabel(context)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (context.rpg.decor.goldIcon(context) case final icon?) ...[
                icon,
                const SizedBox(width: 6),
              ],
              Text('${character.gold} zł', style: _goldValue(context)),
            ],
          ),
        ],
      );
}

class _TraitPills extends StatelessWidget {
  const _TraitPills({required this.traits});

  final List<Trait> traits;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final t in traits) _TraitPill(trait: t),
        ],
      );
}

/// One trait. Kurczaki adds a feather before the name and lays the value
/// in a yolk-yellow egg.
class _TraitPill extends StatelessWidget {
  const _TraitPill({required this.trait});

  final Trait trait;

  @override
  Widget build(BuildContext context) {
    final rpg = context.rpg;
    final leading = rpg.decor.traitLeading(context);
    final egg = rpg.decor.traitValue(context, trait.value);
    return Container(
      decoration: BoxDecoration(
        color: egg == null ? rpg.crimsonFaint : rpg.parchmentLight,
        border: Border.all(color: rpg.crimsonBorderStrong, width: egg == null ? 1 : 1.5),
        borderRadius: BorderRadius.circular(egg == null ? 10 : 999),
      ),
      padding: EdgeInsets.fromLTRB(egg == null ? 10 : 8, 2, egg == null ? 10 : 3, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 4)],
          Text(
            trait.name,
            style: TextStyle(
              fontFamily: rpg.fontBody,
              fontSize: egg == null ? 10 : 11,
              fontStyle: FontStyle.italic,
              color: rpg.crimson,
            ),
          ),
          const SizedBox(width: 4),
          egg ??
              Text(
                trait.value,
                style: TextStyle(
                  fontFamily: rpg.fontBody,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: rpg.inkHeading,
                ),
              ),
        ],
      ),
    );
  }
}
