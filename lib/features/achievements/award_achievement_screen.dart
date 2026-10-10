import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/change_request.dart';
import '../../models/character.dart';
import '../../models/electronics_days.dart';
import '../../providers/achievement_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/clock_provider.dart';
import '../../providers/seen_achievements_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import '../requests/change_request_form.dart';
import '../requests/styled_fields.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';

/// Awards a badge to [character], or -- with [editing] -- changes an
/// existing badge's presentation. The reward is fixed once awarded: to
/// change it the admin revokes and awards again.
class AwardAchievementScreen extends ConsumerStatefulWidget {
  const AwardAchievementScreen({
    super.key,
    required this.character,
    this.editing,
  });

  final Character character;
  final Achievement? editing;

  @override
  ConsumerState<AwardAchievementScreen> createState() =>
      _AwardAchievementScreenState();
}

class _AwardAchievementScreenState
    extends ConsumerState<AwardAchievementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _title;
  late final TextEditingController _event;
  late final TextEditingController _reason;
  late final TextEditingController _date;
  final _days = TextEditingController();
  int? _place;
  late AchievementEmblem _emblem;
  late AchievementTier _tier;
  ChangeSet _changes = const ChangeSet();
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    // One id per form: a double tap or retried transaction re-sends the same
    // badge, which AchievementRepository.award then ignores.
    _id = e?.id ?? ref.read(achievementRepositoryProvider).newId();
    _title = TextEditingController(text: e?.title ?? '');
    _event = TextEditingController(text: e?.event ?? '');
    _reason = TextEditingController(text: e?.reason ?? '');
    _date = TextEditingController(
      text: formatDay(e?.date ?? dayOf(ref.read(clockProvider)())),
    );
    _place = e?.place;
    _emblem = e?.emblem ?? AchievementEmblem.star;
    _tier = e?.tier ?? AchievementTier.gold;
    _title.addListener(_refresh);
    _days.addListener(_refresh);
  }

  @override
  void dispose() {
    for (final c in [_title, _event, _reason, _date, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _pickPlace(int? place) => setState(() {
    _place = place;
    if (place != null) {
      _emblem = AchievementEmblem.place;
      _tier = AchievementTier.forPlace(place);
      _title.text = '${romanPlace(place)} miejsce';
    } else if (_emblem == AchievementEmblem.place) {
      _emblem = AchievementEmblem.trophy;
    }
  });

  String? _blankToNull(String text) => text.trim().isEmpty ? null : text.trim();

  AchievementReward get _reward {
    int? nonZero(num? v) => v == null || v == 0 ? null : v.toInt();
    final trait = _changes.traits
        .where(
          (t) =>
              t.name.trim().isNotEmpty &&
              (num.tryParse(t.value.trim()) ?? 0) != 0,
        )
        .firstOrNull;
    final gold = _changes.gold;
    return AchievementReward(
      currentXp: nonZero(_changes.currentXp),
      gold: gold == null || gold == 0 ? null : gold,
      trait: trait == null
          ? null
          : TraitChange(name: trait.name.trim(), value: trait.value.trim()),
      electronicsDays: nonZero(int.tryParse(_days.text.trim())),
    );
  }

  AchievementDetails get _details => AchievementDetails(
    title: _title.text.trim(),
    event: _blankToNull(_event.text),
    reason: _blankToNull(_reason.text),
    date: parseDay(_date.text.trim()) ?? dayOf(ref.read(clockProvider)()),
    emblem: _emblem,
    place: _emblem == AchievementEmblem.place ? _place : null,
    tier: _tier,
  );

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    setState(() => _saving = true);
    final repo = ref.read(achievementRepositoryProvider);
    try {
      final editing = widget.editing;
      if (editing != null) {
        await repo.edit(widget.character.id, editing.id, _details);
      } else {
        await repo.award(
          widget.character.id,
          Achievement.fromDetails(
            id: _id,
            details: _details,
            reward: _reward,
            awardedBy: user.uid,
            awardedByName: user.name,
            awardedAt: ref.read(clockProvider)(),
          ),
        );
        // The admin who awarded it has seen it: no NOWA on their own card view.
        ref.read(seenAchievementsProvider.notifier).markSeen(_id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Zapis nieudany: $error')));
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text.toUpperCase(), style: fieldLabel),
  );

  @override
  Widget build(BuildContext context) {
    // Watched, not just read in _submit: a bare read of an unlistened
    // StreamProvider is still loading and would make submit a silent no-op.
    ref.watch(appUserProvider);
    final name = widget.character.name;
    final title = _title.text.trim().isEmpty ? '…' : _title.text.trim();
    final parts = rewardParts(_reward);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: achievementAppBar(
        _isEdit ? 'Edytuj odznakę' : 'Przyznaj odznakę · $name',
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Pinned above the scrolling form so the live preview stays in
            // view while the admin picks place, emblem and tier.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  AchievementBadge(
                    tier: _tier,
                    emblem: _emblem,
                    place: _place,
                    size: 72,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: fontDisplay,
                        fontSize: 20,
                        color: parchmentLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: cardGradient,
                      border: Border.all(color: crimson, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('Zajęte miejsce'),
                        Row(
                          children: [
                            for (final p in [1, 2, 3, null])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: _Choice(
                                    key: Key('place-${p ?? 'none'}'),
                                    selected: _place == p,
                                    onTap: () => _pickPlace(p),
                                    child: Text(
                                      p == null ? 'brak' : romanPlace(p),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        _label('Emblemat'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in AchievementEmblem.values)
                              _Choice(
                                key: Key('emblem-${e.wire}'),
                                circle: true,
                                selected: _emblem == e,
                                onTap: () => setState(() => _emblem = e),
                                child: e == AchievementEmblem.place
                                    ? const Text('I')
                                    : Icon(switch (e) {
                                        AchievementEmblem.trophy =>
                                          Icons.emoji_events,
                                        AchievementEmblem.note =>
                                          Icons.music_note,
                                        AchievementEmblem.peak =>
                                          Icons.landscape,
                                        AchievementEmblem.book =>
                                          Icons.menu_book,
                                        _ => Icons.star,
                                      }, size: 20),
                              ),
                          ],
                        ),
                        _label('Kruszec'),
                        Row(
                          children: [
                            for (final t in AchievementTier.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: _Choice(
                                    key: Key('tier-${t.wire}'),
                                    selected: _tier == t,
                                    onTap: () => setState(() => _tier = t),
                                    child: Text(tierLabel(t)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        _label('Tytuł'),
                        boxedField(
                          key: const Key('field-title'),
                          controller: _title,
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Podaj tytuł' : null,
                        ),
                        _label('Wydarzenie'),
                        boxedField(
                          key: const Key('field-event'),
                          controller: _event,
                        ),
                        _label('Powód'),
                        boxedField(
                          key: const Key('field-achievement-reason'),
                          controller: _reason,
                          maxLines: 3,
                        ),
                        _label('Data (RRRR-MM-DD)'),
                        boxedField(
                          key: const Key('field-date'),
                          controller: _date,
                          validator: (v) => parseDay((v ?? '').trim()) == null
                              ? 'Podaj datę RRRR-MM-DD'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const LabelledDivider(label: 'Nagroda'),
                        const SizedBox(height: 10),
                        if (_isEdit) ...[
                          RewardChips(reward: widget.editing!.reward),
                          const SizedBox(height: 8),
                          const Text(
                            'Aby zmienić nagrodę, usuń odznakę i przyznaj ją ponownie.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: crimson,
                            ),
                          ),
                        ] else ...[
                          ChangeRequestForm(
                            showReason: false,
                            onChanged: (changes, _) =>
                                setState(() => _changes = changes),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Dni elektroniki'.toUpperCase(),
                                style: fieldLabel,
                              ),
                              SizedBox(
                                width: stepperWidth,
                                child: stepperField(
                                  fieldKey: const Key('field-electronics-days'),
                                  controller: _days,
                                  stepSize: 1,
                                  iconSize: 36,
                                  validator: (v) =>
                                      validateOptionalDelta(v, decimal: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '$name otrzyma odznakę „$title”'
                            '${parts.isEmpty ? '.' : ': ${parts.join(', ')}.'}',
                            style: const TextStyle(
                              fontFamily: fontBody,
                              fontSize: 13,
                              color: inkHeading,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('achievement-submit'),
                          onPressed: _saving ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: crimson,
                            foregroundColor: parchmentLight,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                              side: const BorderSide(color: goldGlyph),
                            ),
                          ),
                          child: Text(
                            (_isEdit ? 'Zapisz' : 'Przyznaj').toUpperCase(),
                            style: const TextStyle(
                              fontFamily: fontDisplay,
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
          ],
        ),
      ),
    );
  }
}

/// A selectable plaque (or circle) for the place / emblem / tier pickers.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.circle = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: selected ? gold : crimsonBorder);
    final ShapeBorder shape = circle
        ? CircleBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: side,
          );
    final fg = selected ? parchmentLight : crimson;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? crimsonDeep : crimsonBgFaint,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            width: circle ? 44 : null,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: fg,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
