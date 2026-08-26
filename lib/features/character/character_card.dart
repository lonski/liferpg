import 'package:flutter/material.dart';

import '../../feature_flags.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'edit_character_screen.dart';

const TextStyle kStatLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  letterSpacing: 2,
  color: crimson,
);

// .xpMeta -- the "Doświadczenie" label and the "n / n XP" counter share this
// style; neither is uppercase and neither uses the display font.
const TextStyle _xpMetaText = TextStyle(
  fontFamily: fontBody,
  fontSize: 10,
  fontStyle: FontStyle.italic,
  color: crimson,
);

// .traitsDividerLabel
const TextStyle _traitsDividerLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 8,
  letterSpacing: 3,
  color: crimson,
);

class CharacterCard extends StatefulWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.canEdit,
  });

  final Character character;
  final bool canEdit;

  @override
  State<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<CharacterCard> {
  bool _hintVisible = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: crimson, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: cardShadowColor, blurRadius: 24, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopBand(
            label: '✦ Karta Postaci ✦',
            trailing: widget.canEdit
                ? IconButton(
                    key: const Key('edit-character'),
                    tooltip: 'Edytuj postać',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 16,
                    color: parchmentSoft,
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
            decoration: const BoxDecoration(gradient: cardGradient),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: crimsonBorder),
                    borderRadius: BorderRadius.circular(2),
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
                      if (kShowFavour) ...[
                        const SizedBox(height: 8),
                        Text(
                          favourEmoji(c.favour),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                      if (c.traits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const _TraitsHeading(),
                        const SizedBox(height: 8),
                        _TraitPills(traits: c.traits),
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
    );
  }
}

/// Mood glyph, matching the React FavourEmoji thresholds exactly.
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
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: inkHeading,
            ),
          ),
          if (character.clazz != null)
            Text(
              character.clazz!.toUpperCase(),
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 9,
                letterSpacing: 4,
                color: crimson,
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
          Text('Poziom'.toUpperCase(), style: kStatLabel),
          Container(
            decoration: BoxDecoration(
              color: crimsonFaint,
              border: Border.all(color: crimsonBorderStrong),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: inkHeading,
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
              const Text('Doświadczenie', style: _xpMetaText),
              Text(
                '${character.currentXp} / ${character.nextLevelXp} XP',
                style: _xpMetaText,
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            key: const Key('xp-bar'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: crimsonFaint,
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(2),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: character.xpFraction,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: xpGradient),
                ),
              ),
            ),
          ),
          // React shows/hides this hint with no transition; no AnimatedSize.
          if (hintVisible)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: crimsonBgFaint,
                  border: Border.all(color: crimsonBorderFaint),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Text(
                  'Do następnego poziomu: ${character.xpRemaining} XP',
                  style: const TextStyle(
                    fontFamily: fontBody,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: crimson,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _GoldRow extends StatelessWidget {
  const _GoldRow({required this.character});

  static const TextStyle _goldValue = TextStyle(
    fontFamily: fontBody,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: inkHeading,
  );

  final Character character;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Złoto'.toUpperCase(), style: kStatLabel),
          Row(
            children: [
              Text('${character.gold} zł', style: _goldValue),
              if (character.goldUsd != null) ...[
                const Text(' · ', style: TextStyle(color: crimson)),
                Text('${character.goldUsd} \$', style: _goldValue),
              ],
            ],
          ),
        ],
      );
}

class _TraitsHeading extends StatelessWidget {
  const _TraitsHeading();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: crimsonBorderStrong, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Cechy'.toUpperCase(), style: _traitsDividerLabel),
          ),
          const Expanded(child: Divider(color: crimsonBorderStrong, height: 1)),
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
          for (final t in traits)
            Container(
              decoration: BoxDecoration(
                color: crimsonFaint,
                border: Border.all(color: crimsonBorderStrong),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: crimson,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.value,
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: inkHeading,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
