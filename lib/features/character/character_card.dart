import 'package:flutter/material.dart';

import '../../feature_flags.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'edit_character_screen.dart';

const TextStyle kStatLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 2,
  color: crimson,
);

const Color _inkHeading = Color(0xFF2D0A0A);

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
          BoxShadow(color: Color(0xB3000000), blurRadius: 32, offset: Offset(0, 8)),
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
                    color: parchmentMuted,
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: _inkHeading,
            ),
          ),
          if (character.clazz != null)
            Text(
              character.clazz!,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 10,
                fontStyle: FontStyle.italic,
                letterSpacing: 1,
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
          const Text('Poziom', style: kStatLabel),
          Container(
            decoration: BoxDecoration(
              gradient: bandGradient,
              border: Border.all(color: goldBorder),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: parchmentLight,
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
              const Text('Doświadczenie', style: kStatLabel),
              Text(
                '${character.currentXp} / ${character.nextLevelXp} XP',
                style: const TextStyle(
                  fontFamily: fontBody,
                  fontSize: 10,
                  color: crimson,
                ),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: hintVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Do następnego poziomu: ${character.xpRemaining} XP',
                      style: const TextStyle(
                        fontFamily: fontBody,
                        fontSize: 10,
                        color: crimson,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
}

class _GoldRow extends StatelessWidget {
  const _GoldRow({required this.character});

  static const TextStyle _goldValue = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF8A5A06),
  );

  final Character character;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Złoto', style: kStatLabel),
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
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: crimsonBorder, height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Cechy', style: kStatLabel),
          ),
          Expanded(child: Divider(color: crimsonBorder, height: 1)),
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
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 9,
                      letterSpacing: 1,
                      color: crimson,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.value,
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _inkHeading,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
