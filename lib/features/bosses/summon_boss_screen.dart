import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/boss.dart';
import '../../models/change_request.dart';
import '../../models/character.dart';
import '../../providers/auth_providers.dart';
import '../../providers/boss_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import '../achievements/achievement_widgets.dart';
import '../requests/styled_fields.dart';
import 'boss_art.dart';

/// An admin calls a boss: its look, name, HP, the reward every fighter
/// collects, and whose cards it appears under.
class SummonBossScreen extends ConsumerStatefulWidget {
  const SummonBossScreen({super.key});

  /// Seeds the "Losowy" pick; tests replace it.
  @visibleForTesting
  static math.Random random = math.Random();

  @override
  ConsumerState<SummonBossScreen> createState() => _SummonBossScreenState();
}

class _TraitRow {
  _TraitRow(this.id);

  final int id;
  final name = TextEditingController();
  final value = TextEditingController(text: '1');

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _SummonBossScreenState extends ConsumerState<SummonBossScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: BossLook.smok.label);
  final _hp = TextEditingController(text: '100');
  final _xp = TextEditingController(text: '50');
  final _gold = TextEditingController();
  final _traits = <_TraitRow>[];
  int _nextTrait = 0;

  /// Null: Losowy.
  BossLook? _look = BossLook.smok;
  bool _nameEdited = false;
  Character? _target;
  bool _forOne = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      final auto = _look?.label ?? '';
      if (_name.text != auto) _nameEdited = true;
    });
    for (final c in [_xp, _gold, _hp]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _hp, _xp, _gold]) {
      c.dispose();
    }
    for (final t in _traits) {
      t.dispose();
    }
    super.dispose();
  }

  void _pickLook(BossLook? look) {
    setState(() => _look = look);
    if (!_nameEdited || _name.text.trim().isEmpty) {
      _name.text = look?.label ?? '';
      _nameEdited = false;
    }
  }

  void _addTrait() => setState(() => _traits.add(_TraitRow(_nextTrait++)));

  void _removeTrait(_TraitRow row) => setState(() {
    _traits.remove(row);
    row.dispose();
  });

  BossReward get _reward {
    final xp = int.tryParse(_xp.text.trim());
    final gold = num.tryParse(_gold.text.trim());
    return BossReward(
      currentXp: xp == null || xp == 0 ? null : xp,
      gold: gold == null || gold == 0 ? null : gold,
      traits: [
        for (final t in _traits)
          if (t.name.text.trim().isNotEmpty &&
              (num.tryParse(t.value.text.trim()) ?? 0) != 0)
            TraitChange(name: t.name.text.trim(), value: t.value.text.trim()),
      ],
    );
  }

  Future<void> _submit(List<Character> roster) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final reward = _reward;
    if (reward.isEmpty) {
      _snack('Ustaw nagrodę: XP, złoto albo cechę');
      return;
    }
    if (_forOne && _target == null) {
      _snack('Wybierz postać');
      return;
    }
    final look =
        _look ??
        BossLook.values[SummonBossScreen.random.nextInt(
          BossLook.values.length,
        )];
    final name = _name.text.trim().isEmpty ? look.label : _name.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(bossRepositoryProvider)
          .summon(
            name: name,
            look: look,
            hp: int.parse(_hp.text.trim()),
            reward: reward,
            target: _forOne ? _target : null,
            targets: _forOne ? [_target!] : roster,
            createdBy: user.uid,
            createdByName: user.name,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Nie udało się przywołać bossa: $e');
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(text.toUpperCase(), style: fieldLabel(context)),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(appUserProvider);
    final t = context.rpg;
    final roster =
        ref.watch(charactersProvider).value?.characters ?? const <Character>[];
    final parts = _reward.parts;
    final who = _forOne ? (_target?.name ?? '…') : 'wszystkich';

    return Scaffold(
      backgroundColor: t.bgDark,
      appBar: achievementAppBar(context, 'Przywołaj bossa'),
      body: ThemeBackdrop(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: t.cardGradient,
                  border: Border.all(
                    color: t.crimson,
                    width: t.cardBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(t.cardRadius),
                ),
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Wygląd'),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.9,
                      children: [
                        for (final look in BossLook.values)
                          _LookTile(
                            key: Key('look-${look.name}'),
                            selected: _look == look,
                            label: look.label.split(' ').first,
                            onTap: () => _pickLook(look),
                            child: BossArt(look, size: 64),
                          ),
                        _LookTile(
                          key: const Key('look-random'),
                          selected: _look == null,
                          label: 'Losowy',
                          onTap: () => _pickLook(null),
                          child: Icon(
                            Icons.casino_outlined,
                            size: 48,
                            color: t.crimson,
                          ),
                        ),
                      ],
                    ),
                    _label('Imię'),
                    boxedField(
                      key: const Key('boss-name'),
                      controller: _name,
                      validator: (v) =>
                          _look != null && (v ?? '').trim().isEmpty
                          ? 'Podaj imię'
                          : null,
                    ),
                    _label('Życie (HP)'),
                    boxedField(
                      key: const Key('boss-hp-field'),
                      controller: _hp,
                      validator: (v) {
                        final hp = int.tryParse((v ?? '').trim());
                        return hp == null || hp < 1 || hp > 100000
                            ? 'Podaj liczbę od 1'
                            : null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final hp in const [50, 100, 250, 500])
                          ChoiceChip(
                            key: Key('hp-$hp'),
                            label: Text('$hp'),
                            selected: _hp.text.trim() == '$hp',
                            selectedColor: t.crimsonDeep,
                            labelStyle: TextStyle(
                              color: _hp.text.trim() == '$hp'
                                  ? t.parchmentLight
                                  : t.crimson,
                            ),
                            backgroundColor: t.crimsonBgFaint,
                            side: BorderSide(color: t.crimsonBorder),
                            showCheckmark: false,
                            onSelected: (_) => _hp.text = '$hp',
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const LabelledDivider(label: 'Nagroda'),
                    Text(
                      'Dla każdego, kto walczył',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: t.fontBody,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: t.crimson,
                      ),
                    ),
                    _rewardRow(
                      'XP',
                      stepperField(
                        fieldKey: const Key('boss-xp'),
                        controller: _xp,
                        stepSize: stepSize,
                        iconSize: 36,
                        validator: (v) =>
                            validateOptionalDelta(v, decimal: false),
                      ),
                    ),
                    _rewardRow(
                      'Złoto',
                      stepperField(
                        fieldKey: const Key('boss-gold'),
                        controller: _gold,
                        stepSize: stepSize,
                        decimal: true,
                        iconSize: 36,
                        validator: (v) =>
                            validateOptionalDelta(v, decimal: true),
                      ),
                    ),
                    _label('Cechy'),
                    for (final row in _traits)
                      Padding(
                        key: ValueKey(row.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: boxedField(
                                key: Key('boss-trait-name-${row.id}'),
                                controller: row.name,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 120,
                              child: stepperField(
                                fieldKey: Key('boss-trait-value-${row.id}'),
                                controller: row.value,
                                stepSize: 1,
                                validator: (v) =>
                                    validateOptionalDelta(v, decimal: true),
                              ),
                            ),
                            IconButton(
                              key: Key('boss-trait-remove-${row.id}'),
                              tooltip: 'Usuń cechę',
                              color: t.crimson,
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeTrait(row),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('boss-add-trait'),
                        onPressed: _addTrait,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('Dodaj cechę'.toUpperCase()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.crimson,
                          side: BorderSide(color: t.crimsonBorder),
                          textStyle: TextStyle(
                            fontFamily: t.fontDisplay,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    _label('Dla kogo'),
                    Row(
                      children: [
                        for (final one in [false, true])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: _LookTile(
                                key: Key(one ? 'target-one' : 'target-all'),
                                selected: _forOne == one,
                                label: one ? 'Wybrana postać' : 'Wszyscy',
                                compact: true,
                                onTap: () => setState(() => _forOne = one),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_forOne) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in roster)
                            ChoiceChip(
                              key: Key('target-${c.id}'),
                              label: Text(c.name),
                              selected: _target?.id == c.id,
                              selectedColor: t.crimsonDeep,
                              labelStyle: TextStyle(
                                color: _target?.id == c.id
                                    ? t.parchmentLight
                                    : t.crimson,
                              ),
                              backgroundColor: t.crimsonBgFaint,
                              side: BorderSide(color: t.crimsonBorder),
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _target = c),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Boss pojawi się pod kartą: $who'
                      '${parts.isEmpty ? '.' : '. Nagroda: ${parts.join(', ')}.'}',
                      style: TextStyle(
                        fontFamily: t.fontBody,
                        fontSize: 13,
                        color: t.inkHeading,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('summon-boss'),
                      onPressed: _saving ? null : () => _submit(roster),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.crimson,
                        foregroundColor: t.parchmentLight,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.buttonRadius),
                          side: BorderSide(color: t.goldGlyph),
                        ),
                      ),
                      child: Text(
                        'Przywołaj bossa'.toUpperCase(),
                        style: TextStyle(
                          fontFamily: t.fontDisplay,
                          fontSize: 13,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardRow(String label, Widget field) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label.toUpperCase(), style: fieldLabel(context)),
        SizedBox(width: stepperWidth, child: field),
      ],
    ),
  );
}

class _LookTile extends StatelessWidget {
  const _LookTile({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    this.child,
    this.compact = false,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget? child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.tileRadius),
      side: BorderSide(
        color: selected ? t.gold : t.crimsonBorder,
        width: selected ? 2.5 : 1,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.crimsonFaint : t.crimsonBgFaint,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: compact ? 12 : 6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ?child,
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: compact ? t.fontDisplay : t.fontBody,
                    fontSize: compact ? 13 : 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: t.inkHeading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
