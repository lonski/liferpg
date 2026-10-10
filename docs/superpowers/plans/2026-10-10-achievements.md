# Achievements ("Odznaki") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admins award characters badges for real-life accomplishments, each with an individually chosen reward (XP / gold / one trait / electronics days) that is applied on award and reversed on revoke; badges show on the character card and in a gallery, notify the owner, and can be shared as an image. Ships after a small, independent compaction of the electronics section.

**Architecture:** Badges are an `achievements` array inside `characters/{id}` (so visibility and write rules are the character's — `firestore.rules` is untouched). An `AchievementRepository` runs award / edit / revoke as single-document transactions, reusing the change-request delta logic extracted into a pure function. UI lives in `lib/features/achievements/`; notifications and the "Nowa odznaka" dialog ride the existing character stream with a SharedPreferences baseline, same as quest notifications.

**Tech Stack:** Flutter / Dart, Riverpod 3 (`flutter_riverpod`), Cloud Firestore, `flutter_local_notifications`, `share_plus`; tests with `flutter_test`, `fake_cloud_firestore`, `firebase_auth_mocks`.

**Spec:** `docs/superpowers/specs/2026-10-10-achievements-design.md`

## Global Constraints

- UI copy is Polish; label literals stay in normal casing and are uppercased with `.toUpperCase()` at the point of use (CLAUDE.md, UI Language).
- Never call `FirebaseFirestore.instance`, `FirebaseAuth.instance`, `SharedPreferences.getInstance()` outside their providers; read time only through `clockProvider` (repository constructors may default `clock` to `DateTime.now`).
- Colours are `const Color(0xAARRGGBB)` literals, alpha baked in; new ones go in `lib/theme/app_theme.dart`.
- Firestore field names snake_case on existing character fields (`current_xp`, `electronics_days`); badge entry keys exactly as in the spec's data model (`id, title, event, reason, date, emblem, place, tier, reward, awardedBy, awardedByName, awardedAt`).
- `Character.toMap()` must never include `achievements` (nor `electronics`).
- `awardedAt` is a client `Timestamp` — `FieldValue.serverTimestamp()` is rejected inside arrays.
- Reward deltas use change-request semantics; on revoke XP / gold / trait may go negative, electronics days clamp at 0; a trait at 0 stays on the card.
- No changes to `firestore.rules` or `tools/rules-test/`.
- Riverpod 3: `AsyncValue.value` (no `valueOrNull`); a `StreamProvider` needs a listener before `await container.read(x.future)`.
- Before starting: `git fetch && git status` on branch `feature/achievements`.

## Review Focus

1. **First snapshot served from the Firestore cache on a device with no baseline yet** — every existing badge must NOT be announced as new (no notification, no dialog) and no baseline may be seeded from that snapshot. → tests in Task 10.
2. **Double tap on PRZYZNAJ / USUŃ, or a retried transaction** — the reward is applied / reversed exactly once. → id generated once in `initState` (Task 5 test) and idempotency tests in Task 3.
3. **Malformed or legacy `achievements` entries** (missing `id`, stringly numbers, unknown emblem/tier, bad date) — the card and gallery still render; bad entries are dropped or defaulted, never crash. → Task 1 tests.
4. **An admin saves the edit-character screen while a badge was awarded meanwhile** — the badge survives (`update(toMap())` omits `achievements`). → Task 3 test.
5. **Long titles and 2× text scale** on the card section and gallery — no overflow. → Task 7 and Task 8 tests.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/character/electronics_section.dart` (modify) | Task 0 compact layout |
| `lib/models/achievement.dart` (new) | `AchievementEmblem`, `AchievementTier`, `AchievementReward`, `AchievementDetails`, `Achievement` — parsing / serialising |
| `lib/models/achievement_formatting.dart` (new) | Polish dates, tier names, Roman places, reward summary strings |
| `lib/models/character.dart` (modify) | `achievements` field, omitted from `toMap()` |
| `lib/models/character_deltas.dart` (new) | `applyCharacterDeltas` — XP / gold / trait delta logic extracted from `ChangeRequestRepository` |
| `lib/models/electronics_days.dart` (modify) | `addDays` |
| `lib/data/change_request_repository.dart` (modify) | use `applyCharacterDeltas` |
| `lib/data/achievement_repository.dart` (new) | award / edit / revoke transactions |
| `lib/providers/achievement_providers.dart` (new) | `achievementRepositoryProvider`, `characterByIdProvider` |
| `lib/theme/app_theme.dart` (modify) | badge metal colours |
| `lib/theme/dialogs.dart` (modify) | optional `message` on `showConfirmDialog` |
| `lib/features/achievements/achievement_badge.dart` (new) | the medal widget |
| `lib/features/achievements/achievement_widgets.dart` (new) | `achievementAppBar`, `ParchmentFrame`, `RewardChips`, `BadgeGlow` |
| `lib/features/achievements/award_achievement_screen.dart` (new) | award + edit form |
| `lib/features/achievements/achievement_detail_screen.dart` (new) | detail, admin edit / revoke, share |
| `lib/features/achievements/achievements_screen.dart` (new) | gallery |
| `lib/features/achievements/achievements_section.dart` (new) | card section |
| `lib/features/character/character_card.dart` (modify) | `achievements` slot |
| `lib/features/home/home_screen.dart` (modify) | passes the section |
| `lib/features/share/widget_capture.dart` (new) | offscreen PNG capture, extracted from `quest_share.dart` |
| `lib/data/share_service.dart`, `lib/data/share_plus_share_service.dart`, `lib/providers/share_providers.dart` (renamed from quest-specific) | share seam |
| `lib/features/achievements/achievement_share_card.dart`, `achievement_share.dart` (new) | share image + caption |
| `lib/data/achievement_notification_repository.dart` (new) | per-uid notified / celebrated id sets |
| `lib/providers/achievement_notification_providers.dart` (new) | tray notifications + `CelebrationQueue` |
| `lib/features/achievements/new_achievement_dialog.dart`, `achievement_celebration_host.dart` (new) | the "Nowa odznaka" dialog and its host |
| `lib/main.dart` (modify) | watch notifications provider, wrap home in the host |
| `test/features/achievements_test_support.dart` (new, not a test) | shared seeding / pumping helpers |
| `CLAUDE.md` (modify) | docs |

---

### Task 0: Compact electronics section

**Files:**
- Modify: `lib/features/character/electronics_section.dart`
- Test: `test/features/electronics_section_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: same public `ElectronicsSection` constructor; keys `electronics-claim`, `electronics-cancel`, `electronics-ring`, `electronics-count` unchanged.

- [ ] **Step 1: Update the tests to the new layout**

In `test/features/electronics_section_test.dart`:

Replace the two lines
```dart
    expect(find.text('dostępne'), findsOneWidget);
    expect(find.text('DZISIEJSZY DZIEŃ'), findsOneWidget);
```
with
```dart
    expect(find.text('dostępne'), findsNothing);
    expect(find.text('DZISIEJSZY DZIEŃ'), findsNothing);
```

Replace the pending test's title and its `ANULUJ PROŚBĘ` assertion:
```dart
  testWidgets('pending: question headline, status, ANULUJ with tooltip', (tester) async {
```
```dart
    expect(find.text('ANULUJ'), findsOneWidget);
    expect(find.byTooltip('Anuluj prośbę'), findsOneWidget);
```

Append these tests inside `main()`:
```dart
  testWidgets('compact: 52px ring with the action on the same row, to its right',
      (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 320,
      child: ElectronicsSection(
        available: 3,
        state: ElectronicsCardState.charging,
        dayFraction: 0.5,
        onClaim: () {},
      ),
    )));
    expect(tester.getSize(find.byKey(const Key('electronics-ring'))),
        const Size(52, 52));
    final ring = tester.getCenter(find.byKey(const Key('electronics-ring')));
    final button = tester.getCenter(find.byKey(const Key('electronics-claim')));
    expect(button.dx, greaterThan(ring.dx));
    expect((button.dy - ring.dy).abs(), lessThan(4));
  });

  testWidgets('pending with the cancel button fits 320px at 2x text scale',
      (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: wrap(SizedBox(
        width: 320,
        child: ElectronicsSection(
          available: 12,
          state: ElectronicsCardState.pending,
          dayFraction: 0.5,
          onCancel: () {},
        ),
      )),
    ));
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/electronics_section_test.dart`
Expected: FAIL (`dostępne` still found, ring is 84×84, `ANULUJ` not found).

- [ ] **Step 3: Implement the compact layout**

In `lib/features/character/electronics_section.dart`:

Delete the now-unused `_label` style (the `const TextStyle _label = ...` block at the top).

Replace the `action` switch and the returned `Column` in `ElectronicsSection.build` with:
```dart
    final Widget? action = switch (state) {
      ElectronicsCardState.charging when onClaim != null => FilledButton(
          key: const Key('electronics-claim'),
          onPressed: onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: crimson,
            foregroundColor: parchmentLight,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: const BorderSide(color: goldGlyph),
            ),
          ),
          child: Text('Odbierz'.toUpperCase(), style: _buttonText),
        ),
      // The full "Anuluj prośbę" would squeeze the status text on narrow
      // screens now that the button shares the ring's row; it lives on in
      // the tooltip.
      ElectronicsCardState.pending when onCancel != null => Tooltip(
          message: 'Anuluj prośbę',
          child: OutlinedButton(
            key: const Key('electronics-cancel'),
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: crimson,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: crimson),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: Text('Anuluj'.toUpperCase(), style: _buttonText),
          ),
        ),
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LabelledDivider(label: 'Dni elektroniki'),
        const SizedBox(height: 10),
        Row(
          children: [
            _Medallion(
              available: available,
              state: state,
              dayFraction: dayFraction,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: _headline),
                  const SizedBox(height: 2),
                  Text(status, style: _status),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action],
          ],
        ),
      ],
    );
```

Replace `_Medallion.build`'s returned `SizedBox` with the 52 px version (count only, smaller state badge):
```dart
    return SizedBox(
      key: const Key('electronics-ring'),
      width: 52,
      height: 52,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(fraction: dayFraction, state: state),
            ),
          ),
          Positioned(
            left: 5,
            top: 5,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: crimsonFaint,
                border: Border.all(color: crimson, width: 2),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$available',
                  key: const Key('electronics-count'),
                  style: const TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: inkHeading,
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.$1,
                  border: Border.all(color: parchmentLight, width: 1.5),
                ),
                child: Icon(badge.$3, size: 9, color: badge.$2),
              ),
            ),
        ],
      ),
    );
```

Update the class doc comment on `ElectronicsSection` to: `/// The "Dni elektroniki" block on a character card: one row with a small ring medallion (the available count), today's state, and at most one compact action at the right. Purely presentational -- ElectronicsPanel decides the state and the callbacks.`

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/electronics_section_test.dart test/features/electronics_panel_test.dart test/features/character_card_test.dart test/features/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Update CLAUDE.md for the new layout**

In `CLAUDE.md`, Key Behaviors → **Electronics days**, replace `a ring medallion with the available count and a gold arc that fills over the local day.` with `a single row: a small (52 px) ring medallion with the available count and a gold arc that fills over the local day, the state text, and at most one compact button at the right end.` and replace `**ANULUJ PROŚBĘ** for the requester only` with `**ANULUJ** (tooltip `Anuluj prośbę`) for the requester only`.

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/features/character/electronics_section.dart test/features/electronics_section_test.dart CLAUDE.md
git commit -m "feat: compact electronics section with the action beside the ring"
```

---

### Task 1: Achievement model and Polish formatting

**Files:**
- Create: `lib/models/achievement.dart`, `lib/models/achievement_formatting.dart`
- Modify: `lib/models/character.dart`
- Test: `test/models/achievement_test.dart`, `test/models/achievement_formatting_test.dart`, `test/models/character_test.dart`

**Interfaces:**
- Consumes: `TraitChange`, `ChangeSet` (`lib/models/change_request.dart`); `dayOf`, `parseDay`, `formatDay` (`lib/models/electronics_days.dart`).
- Produces:
  - `enum AchievementEmblem { place, trophy, note, peak, book, star }` with `String get wire`, `static AchievementEmblem parse(Object?)` (unknown → `star`).
  - `enum AchievementTier { gold, silver, bronze, ruby }` with `wire`, `parse` (unknown → `gold`), `static AchievementTier forPlace(int place)`.
  - `class AchievementReward { int? currentXp; num? gold; TraitChange? trait; int? electronicsDays; bool get isEmpty; factory AchievementReward.fromMap(Object?); Map<String,dynamic> toMap(); AchievementReward negated(); ChangeSet toChangeSet(); }`
  - `class AchievementDetails { String title; String? event; String? reason; int date; AchievementEmblem emblem; int? place; AchievementTier tier; }`
  - `class Achievement { String id; String title; String? event; String? reason; int date; AchievementEmblem emblem; int? place; AchievementTier tier; AchievementReward reward; String awardedBy; String awardedByName; DateTime awardedAt; AchievementEmblem get shownEmblem; bool isNewAt(DateTime now); static Achievement? tryParse(Object?); factory Achievement.fromDetails({...}); Achievement withDetails(AchievementDetails); Map<String,dynamic> toMap(); static int newestFirst(Achievement, Achievement); }`
  - `Character.achievements` (`List<Achievement>`, newest first).
  - Formatting: `String formatPolishDate(int day)`, `String formatShortPolishDate(int day)`, `String romanPlace(int place)`, `String tierLabel(AchievementTier)`, `String tierAdjective(AchievementTier)`, `List<String> rewardParts(AchievementReward)`.

- [ ] **Step 1: Write the failing model tests**

Create `test/models/achievement_test.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/electronics_days.dart';

void main() {
  final awardedAt = DateTime(2026, 9, 12, 18);

  Map<String, dynamic> full() => {
        'id': 'a1',
        'title': 'II miejsce',
        'event': 'Wojewódzki Konkurs Recytatorski',
        'reason': 'Bez kartki.',
        'date': '2026-09-12',
        'emblem': 'place',
        'place': 2,
        'tier': 'silver',
        'reward': {
          'current_xp': 150,
          'gold': 50,
          'traits': [
            {'name': 'Recytacja', 'value': '1'}
          ],
          'electronics_days': 2,
        },
        'awardedBy': 'admin',
        'awardedByName': 'Tata',
        'awardedAt': Timestamp.fromDate(awardedAt),
      };

  test('parses a full entry and round-trips through toMap', () {
    final a = Achievement.tryParse(full())!;
    expect(a.id, 'a1');
    expect(a.title, 'II miejsce');
    expect(a.event, 'Wojewódzki Konkurs Recytatorski');
    expect(a.date, parseDay('2026-09-12'));
    expect(a.emblem, AchievementEmblem.place);
    expect(a.place, 2);
    expect(a.tier, AchievementTier.silver);
    expect(a.reward.currentXp, 150);
    expect(a.reward.gold, 50);
    expect(a.reward.trait, const TraitChange(name: 'Recytacja', value: '1'));
    expect(a.reward.electronicsDays, 2);
    expect(a.awardedAt, awardedAt);
    expect(Achievement.tryParse(a.toMap())!.toMap(), a.toMap());
  });

  test('drops entries without an id or a title', () {
    expect(Achievement.tryParse({...full(), 'id': null}), isNull);
    expect(Achievement.tryParse({...full(), 'title': '  '}), isNull);
    expect(Achievement.tryParse('not a map'), isNull);
  });

  test('tolerates legacy and unknown values', () {
    final a = Achievement.tryParse({
      ...full(),
      'emblem': 'dragon',
      'tier': 'platinum',
      'place': 7,
      'date': 'yesterday',
      'reward': {'current_xp': '20', 'gold': 'lots', 'electronics_days': 1.0},
    })!;
    expect(a.emblem, AchievementEmblem.star);
    expect(a.tier, AchievementTier.gold);
    expect(a.place, isNull);
    expect(a.date, dayOf(awardedAt));
    expect(a.reward.currentXp, 20);
    expect(a.reward.gold, isNull);
    expect(a.reward.electronicsDays, 1);
  });

  test('a place emblem without a valid place shows a trophy', () {
    final a = Achievement.tryParse({...full(), 'place': null})!;
    expect(a.emblem, AchievementEmblem.place);
    expect(a.shownEmblem, AchievementEmblem.trophy);
  });

  test('negated flips every part of the reward', () {
    final r = Achievement.tryParse(full())!.reward.negated();
    expect(r.currentXp, -150);
    expect(r.gold, -50);
    expect(r.trait, const TraitChange(name: 'Recytacja', value: '-1'));
    expect(r.electronicsDays, -2);
  });

  test('reward toMap omits absent parts and toChangeSet carries xp/gold/trait', () {
    const r = AchievementReward(currentXp: 10);
    expect(r.toMap(), {'current_xp': 10});
    expect(const AchievementReward().isEmpty, isTrue);
    final cs = const AchievementReward(
      gold: 5,
      trait: TraitChange(name: 'Odwaga', value: '1'),
      electronicsDays: 3,
    ).toChangeSet();
    expect(cs.gold, 5);
    expect(cs.traits, [const TraitChange(name: 'Odwaga', value: '1')]);
    expect(cs.electronicsClaim, isNull);
  });

  test('withDetails keeps reward and award stamp', () {
    final a = Achievement.tryParse(full())!;
    final edited = a.withDetails(AchievementDetails(
      title: 'I miejsce',
      date: a.date,
      emblem: AchievementEmblem.place,
      place: 1,
      tier: AchievementTier.gold,
    ));
    expect(edited.title, 'I miejsce');
    expect(edited.event, isNull);
    expect(edited.tier, AchievementTier.gold);
    expect(edited.reward.toMap(), a.reward.toMap());
    expect(edited.awardedAt, a.awardedAt);
  });

  test('newestFirst sorts by date, then by awardedAt', () {
    Achievement at(String id, String date, DateTime awarded) =>
        Achievement.tryParse({
          ...full(),
          'id': id,
          'date': date,
          'awardedAt': Timestamp.fromDate(awarded),
        })!;
    final list = [
      at('old', '2026-01-01', DateTime(2026, 1, 1)),
      at('sameDayEarly', '2026-05-05', DateTime(2026, 5, 5, 8)),
      at('sameDayLate', '2026-05-05', DateTime(2026, 5, 5, 20)),
    ]..sort(Achievement.newestFirst);
    expect(list.map((a) => a.id), ['sameDayLate', 'sameDayEarly', 'old']);
  });

  test('isNewAt is true within 7 days of awardedAt', () {
    final a = Achievement.tryParse(full())!;
    expect(a.isNewAt(awardedAt.add(const Duration(days: 6))), isTrue);
    expect(a.isNewAt(awardedAt.add(const Duration(days: 8))), isFalse);
  });

  test('AchievementTier.forPlace', () {
    expect(AchievementTier.forPlace(1), AchievementTier.gold);
    expect(AchievementTier.forPlace(2), AchievementTier.silver);
    expect(AchievementTier.forPlace(3), AchievementTier.bronze);
  });
}
```

Create `test/models/achievement_formatting_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/achievement_formatting.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/electronics_days.dart';

void main() {
  test('Polish dates', () {
    expect(formatPolishDate(parseDay('2026-09-12')!), '12 września 2026');
    expect(formatShortPolishDate(parseDay('2026-10-04')!), '4 paź 2026');
  });

  test('roman places and tier names', () {
    expect([1, 2, 3].map(romanPlace), ['I', 'II', 'III']);
    expect(tierLabel(AchievementTier.bronze), 'Brąz');
    expect(tierAdjective(AchievementTier.ruby), 'rubinowa');
  });

  test('rewardParts lists only non-zero parts with signs', () {
    expect(
      rewardParts(const AchievementReward(
        currentXp: 150,
        gold: 50,
        trait: TraitChange(name: 'Recytacja', value: '1'),
        electronicsDays: 2,
      )),
      ['+150 XP', '+50 zł', 'Recytacja +1', '+2 dni elektroniki'],
    );
    expect(
      rewardParts(const AchievementReward(gold: -7.5, electronicsDays: -1)),
      ['−7.5 zł', '−1 dzień elektroniki'],
    );
    expect(rewardParts(const AchievementReward(currentXp: 0)), isEmpty);
  });
}
```

Append to `test/models/character_test.dart` (inside `main()`; add `import 'package:cloud_firestore/cloud_firestore.dart';` at the top if missing):
```dart
  test('achievements are parsed newest first, bad entries dropped, never in toMap', () {
    final c = Character.fromMap('c1', {
      'name': 'Zosia',
      'email': 'zosia@example.com',
      'achievements': [
        {'id': 'old', 'title': 'Stara', 'date': '2026-01-01', 'awardedAt': Timestamp.fromDate(DateTime(2026, 1, 1))},
        {'title': 'Bez id'},
        'garbage',
        {'id': 'new', 'title': 'Nowa', 'date': '2026-09-01', 'awardedAt': Timestamp.fromDate(DateTime(2026, 9, 1))},
      ],
    });
    expect(c.achievements.map((a) => a.id), ['new', 'old']);
    expect(c.toMap().containsKey('achievements'), isFalse);
    expect(c.copyWith(name: 'Z').achievements, hasLength(2));
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/models/achievement_test.dart test/models/achievement_formatting_test.dart test/models/character_test.dart`
Expected: FAIL — `achievement.dart` does not exist.

- [ ] **Step 3: Implement `lib/models/achievement.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_request.dart' show ChangeSet, TraitChange;
import 'electronics_days.dart' show dayOf, formatDay, parseDay;

// Badges are written only by this app, but they live on character documents
// whose history argues against trusting the schema -- coerce in the style of
// Character.fromMap rather than throwing.
num? _asNum(Object? v) {
  final n = v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
  return n != null && n.isFinite ? n : null;
}

String? _asText(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

String _negate(String value) {
  final n = -(num.tryParse(value.trim()) ?? 0);
  return n % 1 == 0 ? n.toInt().toString() : '$n';
}

enum AchievementEmblem {
  place,
  trophy,
  note,
  peak,
  book,
  star;

  String get wire => name;

  static AchievementEmblem parse(Object? v) {
    for (final e in values) {
      if (e.name == v) return e;
    }
    return star;
  }
}

enum AchievementTier {
  gold,
  silver,
  bronze,
  ruby;

  String get wire => name;

  static AchievementTier parse(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return gold;
  }

  /// The metal the award form suggests for a podium place.
  static AchievementTier forPlace(int place) => switch (place) {
        1 => gold,
        2 => silver,
        _ => bronze,
      };
}

/// What a badge paid out. XP / gold / trait are deltas with change-request
/// semantics; [electronicsDays] shifts the banked electronics count. Its own
/// class rather than a ChangeSet field: an `electronics_days` key on
/// ChangeSet could ride along in an ordinary change request, which the
/// create rule does not forbid.
class AchievementReward {
  const AchievementReward({
    this.currentXp,
    this.gold,
    this.trait,
    this.electronicsDays,
  });

  final int? currentXp;
  final num? gold;

  /// At most one, matching the single-trait request form.
  final TraitChange? trait;
  final int? electronicsDays;

  bool get isEmpty =>
      currentXp == null && gold == null && trait == null && electronicsDays == null;

  factory AchievementReward.fromMap(Object? raw) {
    if (raw is! Map) return const AchievementReward();
    TraitChange? trait;
    final rawTraits = raw['traits'];
    if (rawTraits is List) {
      for (final t in rawTraits.whereType<Map>()) {
        final parsed = TraitChange.fromMap(Map<String, dynamic>.from(t));
        if (parsed.name.trim().isNotEmpty &&
            num.tryParse(parsed.value.trim()) != null) {
          trait = parsed;
          break;
        }
      }
    }
    return AchievementReward(
      currentXp: _asNum(raw['current_xp'])?.toInt(),
      gold: _asNum(raw['gold']),
      trait: trait,
      electronicsDays: _asNum(raw['electronics_days'])?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (currentXp != null) 'current_xp': currentXp,
        if (gold != null) 'gold': gold,
        if (trait != null) 'traits': [trait!.toMap()],
        if (electronicsDays != null) 'electronics_days': electronicsDays,
      };

  /// The same reward pointing the other way -- what revoking takes back.
  AchievementReward negated() => AchievementReward(
        currentXp: currentXp == null ? null : -currentXp!,
        gold: gold == null ? null : -gold!,
        trait: trait == null
            ? null
            : TraitChange(name: trait!.name, value: _negate(trait!.value)),
        electronicsDays: electronicsDays == null ? null : -electronicsDays!,
      );

  /// The XP / gold / trait part, for applyCharacterDeltas.
  ChangeSet toChangeSet() => ChangeSet(
        currentXp: currentXp,
        gold: gold,
        traits: trait == null ? const [] : [trait!],
      );
}

/// Everything about a badge an admin may change after awarding it: its
/// presentation, never its reward or award stamp.
class AchievementDetails {
  const AchievementDetails({
    required this.title,
    this.event,
    this.reason,
    required this.date,
    required this.emblem,
    this.place,
    required this.tier,
  });

  final String title;
  final String? event;
  final String? reason;

  /// Local calendar day, as `dayOf` counts it.
  final int date;
  final AchievementEmblem emblem;
  final int? place;
  final AchievementTier tier;
}

/// One entry of `characters/{id}.achievements`.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    this.event,
    this.reason,
    required this.date,
    required this.emblem,
    this.place,
    required this.tier,
    this.reward = const AchievementReward(),
    required this.awardedBy,
    required this.awardedByName,
    required this.awardedAt,
  });

  factory Achievement.fromDetails({
    required String id,
    required AchievementDetails details,
    required AchievementReward reward,
    required String awardedBy,
    required String awardedByName,
    required DateTime awardedAt,
  }) =>
      Achievement(
        id: id,
        title: details.title,
        event: details.event,
        reason: details.reason,
        date: details.date,
        emblem: details.emblem,
        place: details.place,
        tier: details.tier,
        reward: reward,
        awardedBy: awardedBy,
        awardedByName: awardedByName,
        awardedAt: awardedAt,
      );

  final String id;
  final String title;
  final String? event;
  final String? reason;
  final int date;
  final AchievementEmblem emblem;

  /// 1-3; only meaningful with [AchievementEmblem.place].
  final int? place;
  final AchievementTier tier;
  final AchievementReward reward;
  final String awardedBy;
  final String awardedByName;

  /// A client timestamp: Firestore rejects serverTimestamp() inside arrays.
  final DateTime awardedAt;

  /// What the medal draws: a place emblem without a place is a trophy.
  AchievementEmblem get shownEmblem =>
      emblem == AchievementEmblem.place && place == null
          ? AchievementEmblem.trophy
          : emblem;

  /// Drives the card's NOWA chip -- a plain age check, no seen-state.
  bool isNewAt(DateTime now) =>
      now.difference(awardedAt) < const Duration(days: 7);

  static Achievement? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = _asText(raw['id']);
    final title = _asText(raw['title']);
    if (id == null || title == null) return null;
    final rawAwardedAt = raw['awardedAt'];
    final awardedAt = rawAwardedAt is Timestamp
        ? rawAwardedAt.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    final place = _asNum(raw['place'])?.toInt();
    return Achievement(
      id: id,
      title: title,
      event: _asText(raw['event']),
      reason: _asText(raw['reason']),
      date: parseDay(raw['date']) ?? dayOf(awardedAt),
      emblem: AchievementEmblem.parse(raw['emblem']),
      place: place != null && place >= 1 && place <= 3 ? place : null,
      tier: AchievementTier.parse(raw['tier']),
      reward: AchievementReward.fromMap(raw['reward']),
      awardedBy: raw['awardedBy'] is String ? raw['awardedBy'] as String : '',
      awardedByName:
          raw['awardedByName'] is String ? raw['awardedByName'] as String : '',
      awardedAt: awardedAt,
    );
  }

  Achievement withDetails(AchievementDetails details) => Achievement.fromDetails(
        id: id,
        details: details,
        reward: reward,
        awardedBy: awardedBy,
        awardedByName: awardedByName,
        awardedAt: awardedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (event != null) 'event': event,
        if (reason != null) 'reason': reason,
        'date': formatDay(date),
        'emblem': emblem.wire,
        if (place != null) 'place': place,
        'tier': tier.wire,
        'reward': reward.toMap(),
        'awardedBy': awardedBy,
        'awardedByName': awardedByName,
        'awardedAt': Timestamp.fromDate(awardedAt),
      };

  static int newestFirst(Achievement a, Achievement b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.awardedAt.compareTo(a.awardedAt);
  }
}
```

- [ ] **Step 4: Implement `lib/models/achievement_formatting.dart`**

```dart
import 'achievement.dart';

const _monthsGenitive = [
  'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
  'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia',
];

const _monthsShort = [
  'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
  'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
];

DateTime _utc(int day) => DateTime.fromMillisecondsSinceEpoch(
      day * Duration.millisecondsPerDay,
      isUtc: true,
    );

/// `12 września 2026`.
String formatPolishDate(int day) {
  final d = _utc(day);
  return '${d.day} ${_monthsGenitive[d.month - 1]} ${d.year}';
}

/// `12 wrz 2026`, for the gallery's tight tiles.
String formatShortPolishDate(int day) {
  final d = _utc(day);
  return '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';
}

String romanPlace(int place) =>
    place >= 1 && place <= 3 ? const ['I', 'II', 'III'][place - 1] : '$place';

String tierLabel(AchievementTier tier) => switch (tier) {
      AchievementTier.gold => 'Złoto',
      AchievementTier.silver => 'Srebro',
      AchievementTier.bronze => 'Brąz',
      AchievementTier.ruby => 'Rubin',
    };

/// Agrees with "odznaka": `Odznaka srebrna`.
String tierAdjective(AchievementTier tier) => switch (tier) {
      AchievementTier.gold => 'złota',
      AchievementTier.silver => 'srebrna',
      AchievementTier.bronze => 'brązowa',
      AchievementTier.ruby => 'rubinowa',
    };

String _signed(num v) {
  final abs = v.abs();
  final text = abs % 1 == 0 ? abs.toInt().toString() : '$abs';
  return v < 0 ? '−$text' : '+$text';
}

/// `['+150 XP', '+50 zł', 'Recytacja +1', '+2 dni elektroniki']` -- zero
/// parts are left out. Shared by chips, the summary line, the revoke
/// confirmation and the notification body.
List<String> rewardParts(AchievementReward r) {
  final traitDelta =
      r.trait == null ? 0 : (num.tryParse(r.trait!.value.trim()) ?? 0);
  final days = r.electronicsDays ?? 0;
  return [
    if ((r.currentXp ?? 0) != 0) '${_signed(r.currentXp!)} XP',
    if ((r.gold ?? 0) != 0) '${_signed(r.gold!)} zł',
    if (traitDelta != 0) '${r.trait!.name} ${_signed(traitDelta)}',
    if (days != 0)
      '${_signed(days)} ${days.abs() == 1 ? 'dzień' : 'dni'} elektroniki',
  ];
}
```

- [ ] **Step 5: Add `achievements` to `Character`**

In `lib/models/character.dart`: add `import 'achievement.dart';`; add constructor parameter `this.achievements = const [],` and field
```dart
  /// Newest first. Written only by AchievementRepository's transactions --
  /// never by toMap(), for the same reason as [electronics].
  final List<Achievement> achievements;
```
In `fromMap`, before `return Character(`:
```dart
    final rawAchievements = data['achievements'];
    final achievements = rawAchievements is List
        ? (rawAchievements
              .map(Achievement.tryParse)
              .whereType<Achievement>()
              .toList()
          ..sort(Achievement.newestFirst))
        : const <Achievement>[];
```
and pass `achievements: achievements,`. In `copyWith`'s constructor call add `achievements: achievements,`. Change the comment above `toMap()` to: `// Deliberately omits `electronics` and `achievements`: the edit screen saves via update(toMap()), and including a snapshot of either here would overwrite a claim accepted, or a badge awarded, while the screen was open.`

- [ ] **Step 6: Run tests**

Run: `flutter test test/models/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/models/achievement.dart lib/models/achievement_formatting.dart lib/models/character.dart test/models/achievement_test.dart test/models/achievement_formatting_test.dart test/models/character_test.dart
git commit -m "feat: achievement model on characters, with Polish formatting"
```

---

### Task 2: Shared delta function and `ElectronicsDays.addDays`

**Files:**
- Create: `lib/models/character_deltas.dart`
- Modify: `lib/data/change_request_repository.dart` (`_applyTo`, ~lines 277-343), `lib/models/electronics_days.dart`
- Test: `test/models/character_deltas_test.dart`, `test/models/electronics_days_test.dart`

**Interfaces:**
- Consumes: `ChangeSet`.
- Produces: `Map<String, dynamic> applyCharacterDeltas(Map<String, dynamic> character, ChangeSet changes)` (XP / gold / traits only; ignores `electronicsClaim`); `ElectronicsDays addDays(int delta, int today)`.

- [ ] **Step 1: Write the failing tests**

Create `test/models/character_deltas_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character_deltas.dart';

void main() {
  test('only touched fields appear', () {
    expect(applyCharacterDeltas({'gold': 10}, const ChangeSet(currentXp: 5)),
        {'current_xp': 5});
  });

  test('xp is whole, gold keeps fractions, legacy strings coerce', () {
    final u = applyCharacterDeltas(
      {'current_xp': '40', 'gold': 'n/a'},
      const ChangeSet(currentXp: 10.7, gold: 2.5),
    );
    expect(u['current_xp'], 50);
    expect(u['gold'], 2.5);
  });

  test('may go negative', () {
    final u = applyCharacterDeltas({'current_xp': 10, 'gold': 10},
        const ChangeSet(currentXp: -150, gold: -50));
    expect(u, {'current_xp': -140, 'gold': -40});
  });

  test('traits add by name, append new names verbatim, keep zero', () {
    final u = applyCharacterDeltas({
      'traits': [
        {'name': 'Recytacja', 'value': '1'},
        {'name': 'Siła', 'value': '18'},
      ],
    }, const ChangeSet(traits: [
      TraitChange(name: 'Recytacja', value: '-1'),
    ]));
    expect(u['traits'], [
      {'name': 'Recytacja', 'value': '0'},
      {'name': 'Siła', 'value': '18'},
    ]);
    final appended = applyCharacterDeltas({},
        const ChangeSet(traits: [TraitChange(name: 'Odwaga', value: '-1')]));
    expect(appended['traits'], [
      {'name': 'Odwaga', 'value': '-1'}
    ]);
  });
}
```

Append to `test/models/electronics_days_test.dart` inside `main()`:
```dart
  group('addDays', () {
    final today = parseDay('2026-10-20')!;

    test('settles accrual before adding', () {
      final e = ElectronicsDays(days: 1, asOf: parseDay('2026-10-17')!);
      final next = e.addDays(2, today);
      expect(next.days, 1 + 3 + 2);
      expect(next.asOf, today);
    });

    test('clamps at zero and keeps claimed', () {
      final e = ElectronicsDays(days: 1, asOf: today, claimed: [today - 1]);
      final next = e.addDays(-5, today);
      expect(next.days, 0);
      expect(next.claimed, [today - 1]);
    });

    test('a future as_of stays put', () {
      final e = ElectronicsDays(days: 2, asOf: today + 1);
      expect(e.addDays(1, today).asOf, today + 1);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/models/character_deltas_test.dart test/models/electronics_days_test.dart`
Expected: FAIL — `character_deltas.dart` missing, `addDays` undefined.

- [ ] **Step 3: Create `lib/models/character_deltas.dart`**

Move the XP / gold / trait body of `ChangeRequestRepository._applyTo` here verbatim (with its comments), as:
```dart
import 'change_request.dart';

/// The character fields to write for the XP / gold / trait part of
/// [changes], given the character's current data. Only fields the change
/// actually touches appear, so an XP-only change cannot invent `gold: 0`.
/// Shared by change-request accept and achievement award / revoke; nothing
/// here clamps, so a negative delta may take a value below zero.
Map<String, dynamic> applyCharacterDeltas(
  Map<String, dynamic> character,
  ChangeSet changes,
) {
  // A field that is absent on the character counts as 0, so `+10 gold`
  // against a character with no `gold` key materialises `gold: 10`.
  num current(String key) {
    final v = character[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim()) ?? 0;
    return 0;
  }

  final updates = <String, dynamic>{
    if (changes.currentXp != null)
      'current_xp': (current('current_xp') + changes.currentXp!).toInt(),
    if (changes.gold != null) 'gold': current('gold') + changes.gold!,
  };

  if (changes.traits.isNotEmpty) {
    final raw = character['traits'];
    final traits = <Map<String, dynamic>>[
      if (raw is List)
        for (final t in raw.whereType<Map>())
          {
            'name': t['name'] is String ? t['name'] as String : '',
            'value': t['value'] is String ? t['value'] as String : '',
          },
    ];
    for (final change in changes.traits) {
      final index = traits.indexWhere((t) => t['name'] == change.name);
      if (index >= 0) {
        // A trait change is a numeric delta added to the character's
        // current value, mirroring current_xp/gold above -- not a
        // replacement. A value that doesn't parse (an old free-form trait,
        // say) is tolerantly treated as 0, per the same coercion `current`
        // applies to current_xp/gold.
        final currentValue =
            num.tryParse((traits[index]['value'] as String).trim()) ?? 0;
        final delta = num.tryParse(change.value.trim()) ?? 0;
        final next = currentValue + delta;
        traits[index] = {
          'name': change.name,
          'value': next % 1 == 0 ? next.toInt().toString() : '$next',
        };
      } else {
        // No current value to add to, so the change's value becomes the
        // trait's starting value verbatim.
        traits.add(change.toMap());
      }
    }
    updates['traits'] = traits;
  }

  return updates;
}
```

Then in `lib/data/change_request_repository.dart` add `import '../models/character_deltas.dart';` and replace the whole body of `_applyTo` with:
```dart
    final updates = applyCharacterDeltas(character, changes);

    // An electronics claim spends the day the player tapped, settled
    // against the accepting device's today. applyClaim is a no-op for a
    // date already claimed, so a double accept (or an admin's direct claim
    // in the meantime) can never spend the same day twice.
    final claimDay = parseDay(changes.electronicsClaim);
    if (claimDay != null) {
      updates['electronics'] = ElectronicsDays.fromMap(character['electronics'])
          .applyClaim(claimDay, dayOf(_clock()))
          .toMap();
    }

    return updates;
```
Keep `_applyTo`'s doc comment.

- [ ] **Step 4: Add `addDays` to `ElectronicsDays`**

In `lib/models/electronics_days.dart`, after `withValue`:
```dart
  /// A badge's reward, or its revoke: settles first like every write, then
  /// shifts the banked count by [delta], never below zero.
  ElectronicsDays addDays(int delta, int today) {
    final settled = settle(today);
    return ElectronicsDays(
      days: math.max(0, settled.days + delta),
      asOf: settled.asOf,
      claimed: claimed,
    );
  }
```

- [ ] **Step 5: Run tests (the change-request suite guards the refactor)**

Run: `flutter test test/models/ test/data/change_request_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/models/character_deltas.dart lib/models/electronics_days.dart lib/data/change_request_repository.dart test/models/character_deltas_test.dart test/models/electronics_days_test.dart
git commit -m "refactor: share character delta logic; add ElectronicsDays.addDays"
```

---

### Task 3: `AchievementRepository`

**Files:**
- Create: `lib/data/achievement_repository.dart`, `lib/providers/achievement_providers.dart`
- Test: `test/data/achievement_repository_test.dart`

**Interfaces:**
- Consumes: `Achievement`, `AchievementDetails`, `AchievementReward` (Task 1); `applyCharacterDeltas`, `ElectronicsDays.addDays` (Task 2); `charactersProvider`, `clockProvider`, `firestoreProvider`.
- Produces:
  - `class AchievementCharacterGone implements Exception` (`'Postać już nie istnieje'`), `class AchievementGone implements Exception` (`'Ta odznaka już nie istnieje'`).
  - `AchievementRepository(FirebaseFirestore db, {DateTime Function()? clock})` with `String newId()`, `Future<void> award(String characterId, Achievement achievement)`, `Future<void> edit(String characterId, String achievementId, AchievementDetails details)`, `Future<void> revoke(String characterId, String achievementId)`.
  - `achievementRepositoryProvider` (`Provider<AchievementRepository>`), `characterByIdProvider` (`Provider.family<Character?, String>`).

- [ ] **Step 1: Write the failing tests**

Create `test/data/achievement_repository_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/achievement_repository.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/models/electronics_days.dart';

final now = DateTime(2026, 10, 12, 10);
final today = dayOf(now);

Achievement badge({String id = 'a1', AchievementReward? reward}) => Achievement(
      id: id,
      title: 'II miejsce',
      event: 'Konkurs',
      date: today,
      emblem: AchievementEmblem.place,
      place: 2,
      tier: AchievementTier.silver,
      reward: reward ??
          const AchievementReward(
            currentXp: 150,
            gold: 50,
            trait: TraitChange(name: 'Recytacja', value: '1'),
            electronicsDays: 2,
          ),
      awardedBy: 'admin',
      awardedByName: 'Tata',
      awardedAt: now,
    );

Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  await db.collection('characters').doc('c1').set({
    'name': 'Zosia',
    'email': 'zosia@example.com',
    'current_xp': 340,
    'gold': 10,
    'traits': [
      {'name': 'Siła', 'value': '5'}
    ],
    'electronics': {'days': 1, 'as_of': formatDay(today), 'claimed': []},
  });
  return db;
}

Future<Map<String, dynamic>> character(FakeFirebaseFirestore db) async =>
    (await db.collection('characters').doc('c1').get()).data()!;

void main() {
  late FakeFirebaseFirestore db;
  late AchievementRepository repo;

  setUp(() async {
    db = await world();
    repo = AchievementRepository(db, clock: () => now);
  });

  test('award appends the badge and applies the whole reward', () async {
    await repo.award('c1', badge());
    final c = await character(db);
    expect(c['achievements'], hasLength(1));
    expect(c['achievements'][0]['id'], 'a1');
    expect(c['current_xp'], 490);
    expect(c['gold'], 60);
    expect(c['traits'], [
      {'name': 'Siła', 'value': '5'},
      {'name': 'Recytacja', 'value': '1'},
    ]);
    expect(c['electronics']['days'], 3);
  });

  test('awarding the same id twice applies it once', () async {
    await repo.award('c1', badge());
    await repo.award('c1', badge());
    final c = await character(db);
    expect(c['achievements'], hasLength(1));
    expect(c['gold'], 60);
  });

  test('an empty reward touches nothing but the list', () async {
    await repo.award('c1', badge(reward: const AchievementReward()));
    final c = await character(db);
    expect(c['gold'], 10);
    expect(c['current_xp'], 340);
  });

  test('award on a missing character throws', () async {
    expect(() => repo.award('nope', badge()),
        throwsA(isA<AchievementCharacterGone>()));
  });

  test('edit changes presentation only', () async {
    await repo.award('c1', badge());
    await repo.edit(
      'c1',
      'a1',
      AchievementDetails(
        title: 'I miejsce',
        date: today,
        emblem: AchievementEmblem.place,
        place: 1,
        tier: AchievementTier.gold,
      ),
    );
    final c = await character(db);
    final entry = c['achievements'][0] as Map;
    expect(entry['title'], 'I miejsce');
    expect(entry['tier'], 'gold');
    expect(entry.containsKey('event'), isFalse);
    expect(entry['reward']['gold'], 50);
    expect(c['gold'], 60);
  });

  test('edit of a missing badge throws AchievementGone', () async {
    expect(
      () => repo.edit(
        'c1',
        'zzz',
        AchievementDetails(
          title: 'X',
          date: today,
          emblem: AchievementEmblem.star,
          tier: AchievementTier.gold,
        ),
      ),
      throwsA(isA<AchievementGone>()),
    );
  });

  test('revoke removes the badge and reverses the reward, below zero', () async {
    await repo.award('c1', badge());
    await db.collection('characters').doc('c1').update({
      'gold': 10, // spent 50 of it meanwhile
      'electronics': {'days': 1, 'as_of': formatDay(today), 'claimed': []},
    });
    await repo.revoke('c1', 'a1');
    final c = await character(db);
    expect(c['achievements'], isEmpty);
    expect(c['current_xp'], 340);
    expect(c['gold'], -40);
    expect(c['traits'], [
      {'name': 'Siła', 'value': '5'},
      {'name': 'Recytacja', 'value': '0'},
    ]);
    expect(c['electronics']['days'], 0);
  });

  test('revoking twice reverses once', () async {
    await repo.award('c1', badge());
    await repo.revoke('c1', 'a1');
    await repo.revoke('c1', 'a1');
    expect((await character(db))['gold'], 10);
  });

  test('saving the edit screen does not wipe badges', () async {
    await repo.award('c1', badge());
    final snap = await db.collection('characters').doc('c1').get();
    final stale = Character.fromMap('c1', {...snap.data()!, 'achievements': []});
    await CharacterRepository(db).updateCharacter(stale.copyWith(name: 'Zosia K.'));
    final c = await character(db);
    expect(c['name'], 'Zosia K.');
    expect(c['achievements'], hasLength(1));
  });

  test('newId is unique per call', () {
    expect(repo.newId(), isNot(repo.newId()));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/achievement_repository_test.dart`
Expected: FAIL — `achievement_repository.dart` missing.

- [ ] **Step 3: Implement `lib/data/achievement_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/achievement.dart';
import '../models/character_deltas.dart';
import '../models/electronics_days.dart';

class AchievementCharacterGone implements Exception {
  const AchievementCharacterGone();

  @override
  String toString() => 'Postać już nie istnieje';
}

class AchievementGone implements Exception {
  const AchievementGone();

  @override
  String toString() => 'Ta odznaka już nie istnieje';
}

/// Award, edit and revoke all read-modify-write `characters/{id}` in one
/// transaction, on the admin's device (there are no Cloud Functions; the
/// character write rule is already admin-only). The badge list and the
/// reward land in the same update, so they can never disagree.
class AchievementRepository {
  AchievementRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> _ref(String characterId) =>
      _db.collection('characters').doc(characterId);

  /// Generated before the transaction, once per award form, so a retried
  /// transaction or a double tap carries the same id and is a no-op.
  String newId() => _db.collection('characters').doc().id;

  Future<void> award(String characterId, Achievement achievement) async {
    final ref = _ref(characterId);
    final today = dayOf(_clock());
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const AchievementCharacterGone();
      final list = _entries(data);
      if (list.any((e) => e is Map && e['id'] == achievement.id)) return;
      tx.update(ref, {
        ..._rewardUpdates(data, achievement.reward, today),
        'achievements': [...list, achievement.toMap()],
      });
    });
  }

  /// Presentation only -- the reward and award stamp are carried over.
  Future<void> edit(
    String characterId,
    String achievementId,
    AchievementDetails details,
  ) async {
    final ref = _ref(characterId);
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const AchievementCharacterGone();
      final list = _entries(data);
      final index = list.indexWhere((e) => e is Map && e['id'] == achievementId);
      final existing = index < 0 ? null : Achievement.tryParse(list[index]);
      if (existing == null) throw const AchievementGone();
      list[index] = existing.withDetails(details).toMap();
      tx.update(ref, {'achievements': list});
    });
  }

  /// Removes the badge and takes its reward back (XP / gold / trait may go
  /// negative; electronics days stop at 0). Already gone: a no-op, so a
  /// double tap cannot reverse twice.
  Future<void> revoke(String characterId, String achievementId) async {
    final ref = _ref(characterId);
    final today = dayOf(_clock());
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const AchievementCharacterGone();
      final list = _entries(data);
      final index = list.indexWhere((e) => e is Map && e['id'] == achievementId);
      if (index < 0) return;
      final reward =
          Achievement.tryParse(list[index])?.reward ?? const AchievementReward();
      list.removeAt(index);
      tx.update(ref, {
        ..._rewardUpdates(data, reward.negated(), today),
        'achievements': list,
      });
    });
  }

  List<Object?> _entries(Map<String, dynamic> data) {
    final raw = data['achievements'];
    return raw is List ? List<Object?>.from(raw) : <Object?>[];
  }

  Map<String, dynamic> _rewardUpdates(
    Map<String, dynamic> character,
    AchievementReward reward,
    int today,
  ) =>
      {
        ...applyCharacterDeltas(character, reward.toChangeSet()),
        if (reward.electronicsDays != null)
          'electronics': ElectronicsDays.fromMap(character['electronics'])
              .addDays(reward.electronicsDays!, today)
              .toMap(),
      };
}
```

- [ ] **Step 4: Implement `lib/providers/achievement_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/achievement_repository.dart';
import '../data/firebase_providers.dart';
import '../models/character.dart';
import 'character_providers.dart';
import 'clock_provider.dart';

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(
    ref.watch(firestoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// One character off the live roster feed: null while the feed loads, or
/// once the character is gone (screens tell the two apart by also watching
/// charactersProvider).
final characterByIdProvider = Provider.family<Character?, String>((ref, id) {
  final feed = ref.watch(charactersProvider).value;
  return feed?.characters.where((c) => c.id == id).firstOrNull;
});
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/data/achievement_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/achievement_repository.dart lib/providers/achievement_providers.dart test/data/achievement_repository_test.dart
git commit -m "feat: achievement award/edit/revoke transactions"
```

---

### Task 4: The medal widget and shared achievement UI bits

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Create: `lib/features/achievements/achievement_badge.dart`, `lib/features/achievements/achievement_widgets.dart`
- Test: `test/features/achievement_badge_test.dart`

**Interfaces:**
- Consumes: `AchievementTier`, `AchievementEmblem`, `Achievement` (Task 1), `romanPlace`, `tierAdjective`, `rewardParts`.
- Produces:
  - `AchievementBadge({Key? key, required AchievementTier tier, required AchievementEmblem emblem, int? place, double size = 120})` and `AchievementBadge.of(Achievement a, {Key? key, double size = 120})`; renders `size × size*1.25`.
  - `PreferredSizeWidget achievementAppBar(String title, {List<Widget> actions = const []})`.
  - `ParchmentFrame({required String band, required Widget child, bool gilded = false, String? footerLabel})`.
  - `RewardChips({required AchievementReward reward})`.
  - `BadgeGlow({required Widget child})`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/achievement_badge_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_badge.dart';
import 'package:liferpg/features/achievements/achievement_widgets.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/change_request.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('a place badge draws its Roman numeral at the requested size',
      (tester) async {
    await tester.pumpWidget(wrap(const AchievementBadge(
      tier: AchievementTier.silver,
      emblem: AchievementEmblem.place,
      place: 2,
      size: 80,
    )));
    expect(find.text('II'), findsOneWidget);
    expect(tester.getSize(find.byType(AchievementBadge)), const Size(80, 100));
    expect(find.bySemanticsLabel('Odznaka srebrna'), findsOneWidget);
  });

  testWidgets('icon emblems, and a place emblem with no place is a trophy',
      (tester) async {
    await tester.pumpWidget(wrap(const Row(mainAxisSize: MainAxisSize.min, children: [
      AchievementBadge(tier: AchievementTier.gold, emblem: AchievementEmblem.note),
      AchievementBadge(tier: AchievementTier.ruby, emblem: AchievementEmblem.place),
    ])));
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
  });

  testWidgets('the numeral ignores text scaling', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(3)),
      child: wrap(const AchievementBadge(
        tier: AchievementTier.bronze,
        emblem: AchievementEmblem.place,
        place: 3,
        size: 32,
      )),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RewardChips shows one chip per non-zero part', (tester) async {
    await tester.pumpWidget(wrap(const RewardChips(
      reward: AchievementReward(
        currentXp: 150,
        gold: 0,
        trait: TraitChange(name: 'Recytacja', value: '1'),
      ),
    )));
    expect(find.text('+150 XP'), findsOneWidget);
    expect(find.text('Recytacja +1'), findsOneWidget);
    expect(find.textContaining('zł'), findsNothing);
  });

  testWidgets('ParchmentFrame bands its title and optional footer', (tester) async {
    await tester.pumpWidget(wrap(const ParchmentFrame(
      band: 'Odznaka',
      footerLabel: 'LifeRPG',
      child: Text('treść'),
    )));
    expect(find.text('✦ ODZNAKA ✦'), findsOneWidget);
    expect(find.text('— ✦ LIFERPG ✦ —'), findsOneWidget);
    expect(find.text('treść'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/achievement_badge_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Add the badge colours to `lib/theme/app_theme.dart`**

After `goldBandGradient`:
```dart
// Achievement badge metals (AchievementBadge): each tier's ring runs
// light -> mid -> dark, and its emblem is inked on the crimson disk. Gold
// reuses `gold` / `goldBandDeep` as mid / dark, ruby `crimsonBright` /
// `crimsonDeep` with a gold rim so it reads against the disk.
const Color badgeGoldLight = Color(0xFFF6DC8E);
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
const Color badgeRubyEmblem = Color(0xFFF0C060);
const Color badgeDiskEdge = Color(0xFF2A0606);
const Color badgeGlow = Color(0x8CF6DC8E); // 55%
const Color badgeGlowFade = Color(0x00F6DC8E); // 0%
```

- [ ] **Step 4: Implement `lib/features/achievements/achievement_badge.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../theme/app_theme.dart';

/// One tier's ring colours. Instances are const and canonical per tier.
class BadgeMetal {
  const BadgeMetal({
    required this.light,
    required this.mid,
    required this.dark,
    required this.rim,
    required this.emblem,
  });

  final Color light;
  final Color mid;
  final Color dark;
  final Color rim;
  final Color emblem;

  static BadgeMetal of(AchievementTier tier) => switch (tier) {
        AchievementTier.gold => const BadgeMetal(
            light: badgeGoldLight, mid: gold, dark: goldBandDeep,
            rim: goldBandDeep, emblem: badgeGoldEmblem),
        AchievementTier.silver => const BadgeMetal(
            light: badgeSilverLight, mid: badgeSilverMid, dark: badgeSilverDark,
            rim: badgeSilverDark, emblem: badgeSilverEmblem),
        AchievementTier.bronze => const BadgeMetal(
            light: badgeBronzeLight, mid: badgeBronzeMid, dark: badgeBronzeDark,
            rim: badgeBronzeDark, emblem: badgeBronzeEmblem),
        AchievementTier.ruby => const BadgeMetal(
            light: badgeRubyLight, mid: crimsonBright, dark: crimsonDeep,
            rim: gold, emblem: badgeRubyEmblem),
      };
}

IconData? _iconFor(AchievementEmblem emblem) => switch (emblem) {
      AchievementEmblem.trophy => Icons.emoji_events,
      AchievementEmblem.note => Icons.music_note,
      AchievementEmblem.peak => Icons.landscape,
      AchievementEmblem.book => Icons.menu_book,
      AchievementEmblem.star => Icons.star,
      AchievementEmblem.place => null,
    };

/// The medal from the "Rodzina odznak" sheet: ribbon tails, a ring in the
/// tier's metal with a milled edge, a crimson disk, and the emblem. Drawn
/// on a 120×150 grid scaled to [size] (the width).
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.tier,
    required this.emblem,
    this.place,
    this.size = 120,
  });

  AchievementBadge.of(Achievement a, {super.key, this.size = 120})
      : tier = a.tier,
        emblem = a.emblem,
        place = a.place;

  final AchievementTier tier;
  final AchievementEmblem emblem;
  final int? place;
  final double size;

  @override
  Widget build(BuildContext context) {
    final metal = BadgeMetal.of(tier);
    final shown = emblem == AchievementEmblem.place && place == null
        ? AchievementEmblem.trophy
        : emblem;
    final icon = _iconFor(shown);
    final s = size / 120;
    return Semantics(
      label: 'Odznaka ${tierAdjective(tier)}',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 1.25,
        child: CustomPaint(
          painter: _BadgePainter(metal),
          child: Stack(
            children: [
              // The disk is centred at (60, 58) on the 120×150 grid.
              Positioned(
                left: 35 * s,
                top: 33 * s,
                width: 50 * s,
                height: 50 * s,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 38 * s, color: metal.emblem)
                      : Text(
                          romanPlace(place!),
                          // A graphic, not prose: it must fit the disk.
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: fontDisplay,
                            fontSize: 30 * s,
                            height: 1,
                            color: metal.emblem,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.metal);

  final BadgeMetal metal;

  static final Path _leftTail = Path()
    ..moveTo(34, 84)
    ..lineTo(56, 96)
    ..lineTo(44, 146)
    ..lineTo(35, 136)
    ..lineTo(24, 144)
    ..close();

  static final Path _rightTail = Path()
    ..moveTo(86, 84)
    ..lineTo(64, 96)
    ..lineTo(76, 146)
    ..lineTo(85, 136)
    ..lineTo(96, 144)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120);

    final ribbon = Paint()..color = crimson;
    final ribbonEdge = Paint()
      ..color = crimsonDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final tail in [_leftTail, _rightTail]) {
      canvas.drawPath(tail, ribbon);
      canvas.drawPath(tail, ribbonEdge);
    }
    final stripe = Paint()
      ..color = metal.mid
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(45, 92), const Offset(34.5, 139), stripe);
    canvas.drawLine(const Offset(75, 92), const Offset(85.5, 139), stripe);

    const c = Offset(60, 58);
    canvas.drawCircle(
      c,
      50,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metal.light, metal.mid, metal.dark],
        ).createShader(Rect.fromCircle(center: c, radius: 50)),
    );
    canvas.drawCircle(
      c,
      50,
      Paint()
        ..color = metal.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Milled edge.
    final milled = Paint()
      ..color = metal.rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const teeth = 56;
    const sweep = 2 * math.pi / teeth;
    final milledRect = Rect.fromCircle(center: c, radius: 45);
    for (var i = 0; i < teeth; i++) {
      canvas.drawArc(milledRect, i * sweep, sweep * 0.4, false, milled);
    }

    canvas.drawCircle(
      c,
      39,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.36),
          radius: 0.75,
          colors: [crimsonBright, badgeDiskEdge],
        ).createShader(Rect.fromCircle(center: c, radius: 39)),
    );
    canvas.drawCircle(
      c,
      39,
      Paint()
        ..color = metal.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      34,
      Paint()
        ..color = metal.mid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _glyph(canvas, const Offset(60, 13.5));
    _glyph(canvas, const Offset(60, 102.5));
    canvas.restore();
  }

  void _glyph(Canvas canvas, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: '✦',
        style: TextStyle(fontSize: 8, height: 1, color: metal.rim),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.metal != metal;
}
```

- [ ] **Step 5: Implement `lib/features/achievements/achievement_widgets.dart`**

```dart
import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

/// The dark gradient AppBar shared by the achievement screens.
PreferredSizeWidget achievementAppBar(
  String title, {
  List<Widget> actions = const [],
}) =>
    AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: parchmentLight,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: appBarGradient,
          border: Border(bottom: BorderSide(color: goldBorderFaint)),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: fontDisplay,
          fontSize: 18,
          letterSpacing: 2,
          color: parchmentLight,
        ),
      ),
      actions: actions,
    );

/// A character-card-style frame: banded top, parchment body with corner
/// ornaments, closing band. [gilded] swaps crimson for the gold band and
/// border (the "Nowa odznaka" dialog, the share image).
class ParchmentFrame extends StatelessWidget {
  const ParchmentFrame({
    super.key,
    required this.band,
    required this.child,
    this.gilded = false,
    this.footerLabel,
  });

  final String band;
  final Widget child;
  final bool gilded;

  /// Written into the closing band (`— ✦ LIFERPG ✦ —`); null keeps the
  /// plain `— ✦ —` BottomBand.
  final String? footerLabel;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: gilded ? gold : crimson, width: 2),
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
              label: '✦ $band ✦',
              gradient: gilded ? goldBandGradient : bandGradient,
              labelColor: gilded ? inkHeading : bandLabelColor,
            ),
            Container(
              decoration: const BoxDecoration(gradient: cardGradient),
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: crimsonBorder),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                  const Positioned(top: 3, left: 3, child: CornerOrnament()),
                  const Positioned(
                    top: 3,
                    right: 3,
                    child: CornerOrnament(mirrored: true),
                  ),
                ],
              ),
            ),
            if (footerLabel == null)
              const BottomBand()
            else
              Container(
                decoration: const BoxDecoration(gradient: bandGradient),
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                child: Text(
                  '— ✦ ${footerLabel!.toUpperCase()} ✦ —',
                  style: const TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 10,
                    letterSpacing: 3,
                    height: 1,
                    color: parchmentMedium,
                  ),
                ),
              ),
          ],
        ),
      );
}

/// One chip per non-zero reward part.
class RewardChips extends StatelessWidget {
  const RewardChips({super.key, required this.reward});

  final AchievementReward reward;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final part in rewardParts(reward))
            Container(
              decoration: BoxDecoration(
                color: crimsonFaint,
                border: Border.all(color: goldBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(
                part,
                style: const TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: inkHeading,
                ),
              ),
            ),
        ],
      );
}

/// A soft gold halo behind a large badge.
class BadgeGlow extends StatelessWidget {
  const BadgeGlow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [badgeGlow, badgeGlowFade]),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}
```

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test test/features/achievement_badge_test.dart && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/theme/app_theme.dart lib/features/achievements/achievement_badge.dart lib/features/achievements/achievement_widgets.dart test/features/achievement_badge_test.dart
git commit -m "feat: achievement medal widget and shared frame/chips"
```

---

### Task 5: Award / edit form

**Files:**
- Create: `lib/features/achievements/award_achievement_screen.dart`, `test/features/achievements_test_support.dart`
- Test: `test/features/award_achievement_screen_test.dart`

**Interfaces:**
- Consumes: `achievementRepositoryProvider` (Task 3), `AchievementBadge`, `achievementAppBar`, `RewardChips` (Task 4), `ChangeRequestForm`, `stepperField`, `boxedField`, `fieldLabel`, `stepperWidth`, `validateOptionalDelta` (`lib/features/requests/`), `appUserProvider`, `clockProvider`.
- Produces: `AwardAchievementScreen({Key? key, required Character character, Achievement? editing})`. Widget keys: `place-1`, `place-2`, `place-3`, `place-none`, `emblem-<wire>`, `tier-<wire>`, `field-title`, `field-event`, `field-achievement-reason`, `field-date`, `field-electronics-days`, `achievement-submit`. Test support: `testNow`, `seedWorld`, `zosiaCharacter`, `achievementMap`, `pumpAchievementsApp`.

- [ ] **Step 1: Create the shared test support**

Create `test/features/achievements_test_support.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in flutter_riverpod's misc.dart, not its main barrel.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/providers/clock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final testNow = DateTime(2026, 10, 12, 10);

Map<String, dynamic> achievementMap({
  String id = 'a1',
  String title = 'II miejsce',
  String date = '2026-09-12',
  String emblem = 'place',
  int? place = 2,
  String tier = 'silver',
  Map<String, dynamic> reward = const {
    'current_xp': 150,
    'gold': 50,
    'traits': [
      {'name': 'Recytacja', 'value': '1'}
    ],
    'electronics_days': 2,
  },
  DateTime? awardedAt,
}) =>
    {
      'id': id,
      'title': title,
      'event': 'Wojewódzki Konkurs Recytatorski',
      'reason': 'Bez kartki, bez zająknięcia.',
      'date': date,
      'emblem': emblem,
      if (place != null) 'place': place,
      'tier': tier,
      'reward': reward,
      'awardedBy': 'admin',
      'awardedByName': 'Tata',
      'awardedAt': Timestamp.fromDate(awardedAt ?? DateTime(2026, 9, 12, 18)),
    };

Map<String, dynamic> zosiaCharacter({
  List<Map<String, dynamic>> achievements = const [],
}) =>
    {
      'name': 'Zosia',
      'clazz': 'Bardka',
      'email': 'zosia@example.com',
      'level': 7,
      'current_xp': 340,
      'next_level_xp': 500,
      'gold': 125,
      'favour': 0,
      'traits': [
        {'name': 'Recytacja', 'value': '3'}
      ],
      'electronics': {'days': 1, 'as_of': '2026-10-12', 'claimed': []},
      if (achievements.isNotEmpty) 'achievements': achievements,
    };

/// Users `admin` (admin@example.com, admin) and `zosia`
/// (zosia@example.com, player), plus character `c1` owned by zosia.
Future<FakeFirebaseFirestore> seedWorld({
  List<Map<String, dynamic>> achievements = const [],
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('admin').set({
    'uid': 'admin', 'name': 'Tata', 'email': 'admin@example.com',
    'admin': true, 'readOnlyOthers': false,
  });
  await db.collection('users').doc('zosia').set({
    'uid': 'zosia', 'name': 'Zosia', 'email': 'zosia@example.com',
    'admin': false, 'readOnlyOthers': false,
  });
  await db
      .collection('characters')
      .doc('c1')
      .set(zosiaCharacter(achievements: achievements));
  return db;
}

Future<Map<String, dynamic>> characterData(FakeFirebaseFirestore db) async =>
    (await db.collection('characters').doc('c1').get()).data()!;

/// Pumps [home] signed in as [uid] ('admin' or 'zosia') and settles.
Future<void> pumpAchievementsApp(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  Widget home, {
  String uid = 'admin',
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: '$uid@example.com'),
      )),
      clockProvider.overrideWithValue(() => testNow),
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: MaterialApp(home: home),
  ));
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Write the failing form tests**

Create `test/features/award_achievement_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_badge.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/character.dart';

import 'achievements_test_support.dart';

Future<Character> zosia(db) async =>
    Character.fromMap('c1', await characterData(db));

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a place sets emblem, tier and title', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
        tester, db, AwardAchievementScreen(character: await zosia(db)));

    await tapKey(tester, 'place-2');
    final badge = tester.widget<AchievementBadge>(find.byType(AchievementBadge));
    expect(badge.emblem, AchievementEmblem.place);
    expect(badge.tier, AchievementTier.silver);
    expect(fieldText(tester, 'field-title'), 'II miejsce');
    expect(fieldText(tester, 'field-date'), '2026-10-12');

    await tapKey(tester, 'place-none');
    expect(tester.widget<AchievementBadge>(find.byType(AchievementBadge)).emblem,
        AchievementEmblem.trophy);
  });

  testWidgets('submitting awards the badge with its reward', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
        tester, db, AwardAchievementScreen(character: await zosia(db)));

    await tapKey(tester, 'place-1');
    await tester.enterText(find.byKey(const Key('field-event')), 'Turniej');
    await tester.enterText(find.byKey(const Key('field-current_xp')), '150');
    await tester.enterText(find.byKey(const Key('field-electronics-days')), '2');
    await tester.pumpAndSettle();
    expect(find.textContaining('Zosia otrzyma odznakę „I miejsce”'), findsOneWidget);
    await tapKey(tester, 'achievement-submit');
    // A second tap would reuse the same id; the repository makes it a no-op.

    final c = await characterData(db);
    expect(c['achievements'], hasLength(1));
    final entry = c['achievements'][0] as Map;
    expect(entry['title'], 'I miejsce');
    expect(entry['event'], 'Turniej');
    expect(entry['tier'], 'gold');
    expect(entry['place'], 1);
    expect(entry['awardedBy'], 'admin');
    expect(entry['awardedByName'], 'Tata');
    expect(entry['reward'], {'current_xp': 150, 'electronics_days': 2});
    expect(c['current_xp'], 490);
    expect(c['electronics']['days'], 3);
  });

  testWidgets('a missing title or bad date blocks the write', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
        tester, db, AwardAchievementScreen(character: await zosia(db)));

    await tester.enterText(find.byKey(const Key('field-date')), '12.10.2026');
    await tapKey(tester, 'achievement-submit');
    expect(find.text('Podaj tytuł'), findsOneWidget);
    expect(find.text('Podaj datę RRRR-MM-DD'), findsOneWidget);
    expect((await characterData(db))['achievements'], isNull);
  });

  testWidgets('edit mode shows the reward read-only and changes details only',
      (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    final c = await zosia(db);
    await pumpAchievementsApp(tester, db,
        AwardAchievementScreen(character: c, editing: c.achievements.single));

    expect(find.byKey(const Key('field-current_xp')), findsNothing);
    expect(find.text('Aby zmienić nagrodę, usuń odznakę i przyznaj ją ponownie.'),
        findsOneWidget);
    expect(find.text('+150 XP'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('field-title')), 'Wyróżnienie');
    await tapKey(tester, 'achievement-submit');
    final data = await characterData(db);
    expect((data['achievements'][0] as Map)['title'], 'Wyróżnienie');
    expect(data['current_xp'], 340);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/award_achievement_screen_test.dart`
Expected: FAIL — `award_achievement_screen.dart` missing.

- [ ] **Step 4: Implement `lib/features/achievements/award_achievement_screen.dart`**

```dart
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
        .where((t) =>
            t.name.trim().isNotEmpty && (num.tryParse(t.value.trim()) ?? 0) != 0)
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                AchievementBadge(
                  tier: _tier,
                  emblem: _emblem,
                  place: _place,
                  size: 96,
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
            const SizedBox(height: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _Choice(
                              key: Key('place-${p ?? 'none'}'),
                              selected: _place == p,
                              onTap: () => _pickPlace(p),
                              child: Text(p == null ? 'brak' : romanPlace(p)),
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
                                  AchievementEmblem.trophy => Icons.emoji_events,
                                  AchievementEmblem.note => Icons.music_note,
                                  AchievementEmblem.peak => Icons.landscape,
                                  AchievementEmblem.book => Icons.menu_book,
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
                            padding: const EdgeInsets.symmetric(horizontal: 3),
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
                  boxedField(key: const Key('field-event'), controller: _event),
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
                    validator: (v) =>
                        parseDay((v ?? '').trim()) == null
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
                        Text('Dni elektroniki'.toUpperCase(), style: fieldLabel),
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
```

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/features/award_achievement_screen_test.dart && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/achievements/award_achievement_screen.dart test/features/achievements_test_support.dart test/features/award_achievement_screen_test.dart
git commit -m "feat: admin form to award and edit achievements"
```

---

### Task 6: Detail screen with edit / revoke

**Files:**
- Create: `lib/features/achievements/achievement_detail_screen.dart`
- Modify: `lib/theme/dialogs.dart`
- Test: `test/features/achievement_detail_screen_test.dart`

**Interfaces:**
- Consumes: `characterByIdProvider`, `charactersProvider`, `achievementRepositoryProvider`, `appUserProvider`, `AwardAchievementScreen`, `AchievementBadge`, `ParchmentFrame`, `RewardChips`, `BadgeGlow`, `achievementAppBar`, formatting helpers.
- Produces: `AchievementDetailScreen({Key? key, required String characterId, required String achievementId})`; keys `achievement-edit`, `achievement-revoke`, `achievement-revoke-confirm`. `showConfirmDialog` gains optional `String? message`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/achievement_detail_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_detail_screen.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';

import 'achievements_test_support.dart';

const screen = AchievementDetailScreen(characterId: 'c1', achievementId: 'a1');

void main() {
  testWidgets('shows the badge details to its owner, without admin actions',
      (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen, uid: 'zosia');

    expect(find.text('II miejsce'), findsOneWidget);
    expect(find.text('Wojewódzki Konkurs Recytatorski'), findsOneWidget);
    expect(find.text('12 września 2026'), findsOneWidget);
    expect(find.text('Tata'), findsOneWidget);
    expect(find.text('+150 XP'), findsOneWidget);
    expect(find.text('+2 dni elektroniki'), findsOneWidget);
    expect(find.byKey(const Key('achievement-edit')), findsNothing);
    expect(find.byKey(const Key('achievement-revoke')), findsNothing);
  });

  testWidgets('admin edit opens the form in edit mode', (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen);
    await tester.tap(find.byKey(const Key('achievement-edit')));
    await tester.pumpAndSettle();
    final form = tester.widget<AwardAchievementScreen>(
        find.byType(AwardAchievementScreen));
    expect(form.editing?.id, 'a1');
  });

  testWidgets('revoke lists what is taken back and reverses the reward',
      (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen);

    await tester.tap(find.byKey(const Key('achievement-revoke')));
    await tester.pumpAndSettle();
    expect(
      find.text('Cofnięte zostanie: −150 XP, −50 zł, Recytacja −1, '
          '−2 dni elektroniki'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('achievement-revoke-confirm')));
    await tester.pumpAndSettle();

    final c = await characterData(db);
    expect(c['achievements'], isEmpty);
    expect(c['gold'], 75);
    expect(c['current_xp'], 190);
  });

  testWidgets('a vanished badge says so', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(tester, db, screen);
    expect(find.text('Ta odznaka już nie istnieje'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/achievement_detail_screen_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Add `message` to `showConfirmDialog`**

In `lib/theme/dialogs.dart` add the parameter `String? message,` after `required String title,`, document it in the doc comment (`[message], when given, is shown as the dialog's body.`), and add to the `AlertDialog`:
```dart
      content: message == null
          ? null
          : Text(
              message,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                height: 1.5,
                color: inkDark,
              ),
            ),
```

- [ ] **Step 4: Implement `lib/features/achievements/achievement_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../providers/achievement_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';
import 'award_achievement_screen.dart';

const TextStyle _metaLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  letterSpacing: 2,
  color: crimson,
);

const TextStyle _metaValue = TextStyle(
  fontFamily: fontBody,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: inkHeading,
);

class AchievementDetailScreen extends ConsumerWidget {
  const AchievementDetailScreen({
    super.key,
    required this.characterId,
    required this.achievementId,
  });

  final String characterId;
  final String achievementId;

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    Character character,
    Achievement achievement,
  ) async {
    final parts = rewardParts(achievement.reward.negated());
    final ok = await showConfirmDialog(
      context,
      title: 'Usunąć odznakę?',
      message: parts.isEmpty
          ? 'Odznaka nie miała nagrody.'
          : 'Cofnięte zostanie: ${parts.join(', ')}',
      cancelLabel: 'Anuluj',
      confirmLabel: 'Usuń',
      confirmKey: const Key('achievement-revoke-confirm'),
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(achievementRepositoryProvider)
          .revoke(character.id, achievement.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Odznaka usunięta')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Nie udało się: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(charactersProvider).value == null;
    final character = ref.watch(characterByIdProvider(characterId));
    final achievement = character?.achievements
        .where((a) => a.id == achievementId)
        .firstOrNull;
    final isAdmin = ref.watch(appUserProvider).value?.admin ?? false;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: achievementAppBar('Odznaka', actions: [
        if (isAdmin && character != null && achievement != null) ...[
          IconButton(
            key: const Key('achievement-edit'),
            tooltip: 'Edytuj',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AwardAchievementScreen(
                character: character,
                editing: achievement,
              ),
            )),
          ),
          IconButton(
            key: const Key('achievement-revoke'),
            tooltip: 'Usuń',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _revoke(context, ref, character, achievement),
          ),
        ],
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : achievement == null
              ? const Center(
                  child: Text(
                    'Ta odznaka już nie istnieje',
                    style: TextStyle(fontFamily: fontBody, color: parchmentLight),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: BadgeGlow(
                        child: AchievementBadge.of(achievement, size: 150),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ParchmentFrame(
                      band: 'Odznaka ${tierAdjective(achievement.tier)}',
                      child: _Body(achievement: achievement),
                    ),
                  ],
                ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          a.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: inkHeading,
          ),
        ),
        if (a.event != null)
          Text(
            a.event!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: fontBody,
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: crimson,
            ),
          ),
        if (a.reason != null) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: crimsonBgFaint,
              border: Border.all(color: crimsonBorderFaint),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.all(10),
            child: Text(
              '„${a.reason}”',
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 14,
                height: 1.35,
                color: inkHeading,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Przyznano'.toUpperCase(), style: _metaLabel),
                  Text(formatPolishDate(a.date), style: _metaValue),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Przyznał'.toUpperCase(), style: _metaLabel),
                  Text(a.awardedByName, style: _metaValue),
                ],
              ),
            ),
          ],
        ),
        if (rewardParts(a.reward).isNotEmpty) ...[
          const SizedBox(height: 14),
          const LabelledDivider(label: 'Nagroda'),
          const SizedBox(height: 10),
          RewardChips(reward: a.reward),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/features/achievement_detail_screen_test.dart test/features/ && flutter analyze`
Expected: PASS (all feature tests — `showConfirmDialog` callers are unaffected by the optional parameter), no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/achievements/achievement_detail_screen.dart lib/theme/dialogs.dart test/features/achievement_detail_screen_test.dart
git commit -m "feat: achievement detail screen with admin edit and revoke"
```

---

### Task 7: Gallery

**Files:**
- Create: `lib/features/achievements/achievements_screen.dart`
- Test: `test/features/achievements_screen_test.dart`

**Interfaces:**
- Consumes: `characterByIdProvider`, `charactersProvider`, `appUserProvider`, `AchievementDetailScreen`, `AwardAchievementScreen`, `AchievementBadge`, `achievementAppBar`, `formatShortPolishDate`.
- Produces: `AchievementsScreen({Key? key, required String characterId})`; keys `achievement-award`, `gallery-tile-<id>`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/achievements_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_detail_screen.dart';
import 'package:liferpg/features/achievements/achievements_screen.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';

import 'achievements_test_support.dart';

final badges = [
  achievementMap(id: 'a1', title: 'II miejsce', date: '2026-09-12'),
  achievementMap(id: 'a2', title: 'Koncert jesienny', date: '2026-10-04',
      emblem: 'note', place: null, tier: 'gold'),
];

void main() {
  testWidgets('lists badges newest first with short dates', (tester) async {
    final db = await seedWorld(achievements: badges);
    await pumpAchievementsApp(
        tester, db, const AchievementsScreen(characterId: 'c1'), uid: 'zosia');
    expect(find.text('Odznaki · Zosia'), findsOneWidget);
    expect(find.text('4 paź 2026'), findsOneWidget);
    final first = tester.getTopLeft(find.byKey(const Key('gallery-tile-a2')));
    final second = tester.getTopLeft(find.byKey(const Key('gallery-tile-a1')));
    expect(first.dx, lessThan(second.dx));
    expect(find.byKey(const Key('achievement-award')), findsNothing);
  });

  testWidgets('a tile opens its detail; admin gets +', (tester) async {
    final db = await seedWorld(achievements: badges);
    await pumpAchievementsApp(
        tester, db, const AchievementsScreen(characterId: 'c1'));
    await tester.tap(find.byKey(const Key('achievement-award')));
    await tester.pumpAndSettle();
    expect(find.byType(AwardAchievementScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gallery-tile-a1')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AchievementDetailScreen>(find.byType(AchievementDetailScreen))
          .achievementId,
      'a1',
    );
  });

  testWidgets('long titles at 2x text scale do not overflow', (tester) async {
    final db = await seedWorld(achievements: [
      achievementMap(
          id: 'long',
          title: 'Zdobywczyni najwyższego szczytu Karkonoszy w zimie'),
    ]);
    await pumpAchievementsApp(
      tester,
      db,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AchievementsScreen(characterId: 'c1'),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/achievements_screen_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement `lib/features/achievements/achievements_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../providers/achievement_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import 'achievement_badge.dart';
import 'achievement_detail_screen.dart';
import 'achievement_widgets.dart';
import 'award_achievement_screen.dart';

/// Every badge of one character, newest first.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key, required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(charactersProvider).value == null;
    final character = ref.watch(characterByIdProvider(characterId));
    final isAdmin = ref.watch(appUserProvider).value?.admin ?? false;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: achievementAppBar(
        character == null ? 'Odznaki' : 'Odznaki · ${character.name}',
        actions: [
          if (isAdmin && character != null)
            IconButton(
              key: const Key('achievement-award'),
              tooltip: 'Przyznaj odznakę',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AwardAchievementScreen(character: character),
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : character == null
              ? const Center(
                  child: Text(
                    'Postać już nie istnieje',
                    style: TextStyle(fontFamily: fontBody, color: parchmentLight),
                  ),
                )
              : _Gallery(character: character),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final all = character.achievements;
    final counts = {
      for (final t in AchievementTier.values)
        t: all.where((a) => a.tier == t).length,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: crimsonDeep,
            border: Border.all(color: goldBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                '${all.length}',
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 26,
                  color: badgeGoldLight,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'zdobytych odznak',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontStyle: FontStyle.italic,
                    color: parchmentMuted,
                  ),
                ),
              ),
              for (final t in AchievementTier.values)
                if (counts[t]! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Tooltip(
                      message: tierLabel(t),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AchievementBadge(
                            tier: t,
                            emblem: AchievementEmblem.star,
                            size: 16,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${counts[t]}',
                            style: const TextStyle(
                              fontFamily: fontBody,
                              fontWeight: FontWeight.w700,
                              color: parchmentLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (all.isEmpty)
          const Center(
            child: Text(
              'Brak odznak',
              style: TextStyle(
                fontFamily: fontBody,
                fontStyle: FontStyle.italic,
                color: parchmentMuted,
              ),
            ),
          ),
        // A Wrap of fixed-width tiles rather than a GridView: tiles grow to
        // their content, so long titles at large text scales never overflow
        // a fixed aspect ratio.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 20) / 3;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in all)
                  SizedBox(
                    width: width,
                    child: _Tile(characterId: character.id, achievement: a),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.characterId, required this.achievement});

  final String characterId;
  final Achievement achievement;

  @override
  Widget build(BuildContext context) => Material(
        key: Key('gallery-tile-${achievement.id}'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: crimsonBorderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: cardGradient),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AchievementDetailScreen(
                characterId: characterId,
                achievementId: achievement.id,
              ),
            )),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: Column(
                children: [
                  AchievementBadge.of(achievement, size: 64),
                  const SizedBox(height: 4),
                  Text(
                    achievement.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 12,
                      height: 1.15,
                      color: inkHeading,
                    ),
                  ),
                  Text(
                    formatShortPolishDate(achievement.date),
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: crimson,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
```

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/features/achievements_screen_test.dart && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/achievements/achievements_screen.dart test/features/achievements_screen_test.dart
git commit -m "feat: per-character achievements gallery"
```

---

### Task 8: Card section and home wiring

**Files:**
- Create: `lib/features/achievements/achievements_section.dart`
- Modify: `lib/features/character/character_card.dart`, `lib/features/home/home_screen.dart`
- Test: `test/features/achievements_section_test.dart`, `test/features/character_card_test.dart`

**Interfaces:**
- Consumes: `clockProvider`, `AchievementBadge`, `AchievementsScreen`, `AchievementDetailScreen`, `AwardAchievementScreen`, `LabelledDivider`.
- Produces: `AchievementsSection({Key? key, required Character character, required bool isAdmin})` with `static bool visibleFor(Character c, {required bool isAdmin})`; keys `achievements-award`, `achievements-all`, `achievement-tile-<id>`. `CharacterCard` gains `Widget? achievements`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/achievements_section_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievements_screen.dart';
import 'package:liferpg/features/achievements/achievements_section.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';
import 'package:liferpg/models/character.dart';

import 'achievements_test_support.dart';

Widget host(Character c, {required bool isAdmin}) => Scaffold(
      body: SingleChildScrollView(
        child: AchievementsSection(character: c, isAdmin: isAdmin),
      ),
    );

void main() {
  test('visibleFor: players need a badge, admins always see it', () {
    final none = Character.fromMap('c1', zosiaCharacter());
    final some =
        Character.fromMap('c1', zosiaCharacter(achievements: [achievementMap()]));
    expect(AchievementsSection.visibleFor(none, isAdmin: false), isFalse);
    expect(AchievementsSection.visibleFor(none, isAdmin: true), isTrue);
    expect(AchievementsSection.visibleFor(some, isAdmin: false), isTrue);
  });

  testWidgets('admin with no badges gets Brak odznak and an award button',
      (tester) async {
    final db = await seedWorld();
    final c = Character.fromMap('c1', await characterData(db));
    await pumpAchievementsApp(tester, db, host(c, isAdmin: true));
    expect(find.text('ODZNAKI'), findsOneWidget);
    expect(find.text('Brak odznak'), findsOneWidget);
    await tester.tap(find.byKey(const Key('achievements-award')));
    await tester.pumpAndSettle();
    expect(find.byType(AwardAchievementScreen), findsOneWidget);
  });

  testWidgets('shows the 4 newest with NOWA on recent ones, and links all',
      (tester) async {
    final db = await seedWorld(achievements: [
      for (var i = 1; i <= 5; i++)
        achievementMap(
          id: 'a$i',
          title: 'Odznaka $i',
          date: '2026-10-0$i',
          awardedAt: DateTime(2026, 10, i, 12),
        ),
    ]);
    final c = Character.fromMap('c1', await characterData(db));
    await pumpAchievementsApp(tester, db, host(c, isAdmin: false), uid: 'zosia');

    expect(find.text('ODZNAKI · 5'), findsOneWidget);
    expect(find.byKey(const Key('achievement-tile-a5')), findsOneWidget);
    expect(find.byKey(const Key('achievement-tile-a1')), findsNothing);
    // testNow is 2026-10-12: a5 (Oct 5) is within 7 days, a4 (Oct 4) is not.
    expect(find.text('NOWA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('achievements-all')));
    await tester.pumpAndSettle();
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });

  testWidgets('long titles at 2x scale in a narrow card do not overflow',
      (tester) async {
    final db = await seedWorld(achievements: [
      achievementMap(id: 'x', title: 'Bardzo długi tytuł odznaki za wszystko'),
    ]);
    final c = Character.fromMap('c1', await characterData(db));
    await pumpAchievementsApp(
      tester,
      db,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Center(child: SizedBox(width: 280, child: host(c, isAdmin: false))),
      ),
      uid: 'zosia',
    );
    expect(tester.takeException(), isNull);
  });
}
```

Append to `test/features/character_card_test.dart` inside `main()`:
```dart
  testWidgets('renders the achievements slot after the traits', (tester) async {
    await tester.pumpWidget(wrap(CharacterCard(
      character: sample(traits: const [Trait(name: 'Siła', value: '18')]),
      canEdit: false,
      achievements: const Text('slot-odznak'),
    )));
    expect(find.text('slot-odznak'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('slot-odznak')).dy,
      greaterThan(tester.getTopLeft(find.text('CECHY')).dy),
    );
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/achievements_section_test.dart test/features/character_card_test.dart`
Expected: FAIL — section file missing, `achievements` param unknown.

- [ ] **Step 3: Implement `lib/features/achievements/achievements_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/character.dart';
import '../../providers/clock_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_detail_screen.dart';
import 'achievements_screen.dart';
import 'award_achievement_screen.dart';

const TextStyle _link = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 11,
  letterSpacing: 2,
);

/// The "Odznaki" block on a character card: the four newest badges and a
/// link to the gallery, or -- for an admin, on a character with none yet --
/// a way to award the first.
class AchievementsSection extends ConsumerWidget {
  const AchievementsSection({
    super.key,
    required this.character,
    required this.isAdmin,
  });

  final Character character;
  final bool isAdmin;

  /// Players and readOnlyOthers only see the section once it has something
  /// in it; an admin always does, so the first badge has an entry point.
  static bool visibleFor(Character c, {required bool isAdmin}) =>
      isAdmin || c.achievements.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = character.achievements;
    final now = ref.watch(clockProvider)();
    void push(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabelledDivider(
          label: all.isEmpty ? 'Odznaki' : 'Odznaki · ${all.length}',
        ),
        const SizedBox(height: 8),
        if (all.isEmpty) ...[
          const Text(
            'Brak odznak',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: crimson,
            ),
          ),
          TextButton(
            key: const Key('achievements-award'),
            onPressed: () => push(AwardAchievementScreen(character: character)),
            style: TextButton.styleFrom(foregroundColor: crimson),
            child: Text('Przyznaj odznakę'.toUpperCase(), style: _link),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in all.take(4))
                Expanded(
                  child: _Tile(
                    achievement: a,
                    isNew: a.isNewAt(now),
                    onTap: () => push(AchievementDetailScreen(
                      characterId: character.id,
                      achievementId: a.id,
                    )),
                  ),
                ),
              for (var i = all.length; i < 4; i++)
                const Expanded(child: SizedBox()),
            ],
          ),
          TextButton(
            key: const Key('achievements-all'),
            onPressed: () => push(AchievementsScreen(characterId: character.id)),
            style: TextButton.styleFrom(foregroundColor: crimson),
            child: Text('Wszystkie odznaki ›'.toUpperCase(), style: _link),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.achievement,
    required this.isNew,
    required this.onTap,
  });

  final Achievement achievement;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: Key('achievement-tile-${achievement.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AchievementBadge.of(achievement, size: 50),
                  if (isNew)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        child: Text(
                          'Nowa'.toUpperCase(),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontSize: 8,
                            letterSpacing: 1,
                            color: inkHeading,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: fontBody,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  height: 1.15,
                  color: crimson,
                ),
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 4: Add the slot to `CharacterCard`**

In `lib/features/character/character_card.dart`: add constructor parameter `this.achievements,` and field
```dart
  /// The "Odznaki" section, built by the home screen (it needs providers
  /// this widget deliberately doesn't). Null hides it.
  final Widget? achievements;
```
After the traits block (`if (c.traits.isNotEmpty) ...[ ... ],`) in the inner `Column`, add:
```dart
                      if (widget.achievements != null) ...[
                        const SizedBox(height: 12),
                        widget.achievements!,
                      ],
```

- [ ] **Step 5: Pass the section from `HomeScreen`**

In `lib/features/home/home_screen.dart` add `import '../achievements/achievements_section.dart';` and in the `CharacterCard(...)` call add:
```dart
                      achievements:
                          AchievementsSection.visibleFor(c, isAdmin: isAdmin)
                              ? AchievementsSection(character: c, isAdmin: isAdmin)
                              : null,
```

- [ ] **Step 6: Run the full suite and analyze**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues. If a `home_screen_test.dart` case now fails because an admin's card shows the new `Brak odznak` section (e.g. a `find.byType(TextButton)` count), update that assertion to account for the section — the section is required behaviour for admins.

- [ ] **Step 7: Commit**

```bash
git add lib/features/achievements/achievements_section.dart lib/features/character/character_card.dart lib/features/home/home_screen.dart test/features/achievements_section_test.dart test/features/character_card_test.dart test/features/home_screen_test.dart
git commit -m "feat: achievements section on the character card"
```

---

### Task 9: Sharing

**Files:**
- Create: `lib/features/share/widget_capture.dart`, `lib/providers/share_providers.dart`, `lib/features/achievements/achievement_share_card.dart`, `lib/features/achievements/achievement_share.dart`
- Rename: `lib/data/quest_share_service.dart` → `lib/data/share_service.dart`; `lib/data/share_plus_quest_share_service.dart` → `lib/data/share_plus_share_service.dart`
- Modify: `lib/features/quests/quest_share.dart`, `lib/providers/quest_providers.dart`, `lib/features/achievements/achievement_detail_screen.dart`, `test/features/quest_share_test.dart`
- Test: `test/features/achievement_share_test.dart`

**Interfaces:**
- Consumes: `ParchmentFrame`, `RewardChips`, `BadgeGlow`, `AchievementBadge`, formatting helpers.
- Produces:
  - `Future<Uint8List?> captureWidgetImage(BuildContext context, Widget child, {double width = 360})`.
  - `abstract class ShareService { Future<void> share({required String text, Uint8List? imageBytes, String? imageName}); }`, `SharePlusShareService`, `shareServiceProvider` (`Provider<ShareService>`).
  - `AchievementShareCard({required Character character, required Achievement achievement})`.
  - `typedef WidgetCapture = Future<Uint8List?> Function(BuildContext context, Widget child, {double width});`
  - `String achievementShareCaption(String characterName, Achievement a)`; `Future<void> shareAchievement(BuildContext context, WidgetRef ref, Character character, Achievement achievement, {WidgetCapture capture = captureWidgetImage})`.
  - Detail screen key `achievement-share`.

- [ ] **Step 1: Rename the share seam (pure refactor)**

```bash
git mv lib/data/quest_share_service.dart lib/data/share_service.dart
git mv lib/data/share_plus_quest_share_service.dart lib/data/share_plus_share_service.dart
```
In `lib/data/share_service.dart` rename `QuestShareService` → `ShareService` and reword the doc to: `/// The seam through which the app hands an image + caption to Android's native share sheet (quests and achievements), and through which tests swap in a fake. Image bytes are optional so a failed capture can still fall back to a text-only share.`
In `lib/data/share_plus_share_service.dart` rename `SharePlusQuestShareService` → `SharePlusShareService`, its import to `share_service.dart`, `implements ShareService`, and the fallback name `'quest.png'` → `'liferpg.png'`.

Create `lib/providers/share_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/share_plus_share_service.dart';
import '../data/share_service.dart';

/// Overridden with a fake in tests, same seam pattern as
/// `changeRequestNotificationServiceProvider`.
final shareServiceProvider = Provider<ShareService>(
  (ref) => const SharePlusShareService(),
);
```
In `lib/providers/quest_providers.dart` delete `questShareServiceProvider` and the two share imports.

Create `lib/features/share/widget_capture.dart` by moving `_captureQuestCardImage` out of `quest_share.dart`, generalised:
```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [child] offscreen at a fixed [width] (an [Overlay] entry
/// positioned well outside the viewport) so its pixels don't depend on
/// whatever width the caller happened to be laid out at, then rasterises it
/// via [RenderRepaintBoundary]. Two frames are awaited: the first mounts and
/// lays the copy out, the second guarantees it has actually painted before
/// `toImage` runs.
Future<Uint8List?> captureWidgetImage(
  BuildContext context,
  Widget child, {
  double width = 360,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -9999,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
```
Rewrite `lib/features/quests/quest_share.dart` to use it:
```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quest_deep_link.dart';
import '../../models/quest.dart';
import '../../providers/share_providers.dart';
import '../share/widget_capture.dart';
import 'quest_card.dart';

/// Captures [quest]'s card as a PNG and hands it, plus a caption carrying the
/// quest's title and its deep link, to [shareServiceProvider] -- which opens
/// Android's native share sheet. A failed capture (rare) degrades to a
/// text-only share rather than failing the whole action.
Future<void> shareQuest(BuildContext context, WidgetRef ref, Quest quest) async {
  final service = ref.read(shareServiceProvider);
  final text = '${quest.title}\n${questDeepLink(quest.id)}';
  Uint8List? imageBytes;
  try {
    imageBytes = await captureWidgetImage(context, QuestCard(quest: quest));
  } catch (e) {
    debugPrint('Falling back to a text-only share for quest ${quest.id}: $e');
  }
  await service.share(
    text: text,
    imageBytes: imageBytes,
    imageName: 'quest-${quest.id}.png',
  );
}
```
In `test/features/quest_share_test.dart`: import `package:liferpg/data/share_service.dart` and `package:liferpg/providers/share_providers.dart` instead of the quest-specific ones; `_FakeQuestShareService implements ShareService`; override `shareServiceProvider`.

Run: `grep -rn "QuestShareService\|questShareServiceProvider\|quest_share_service\|share_plus_quest" lib test`
Expected: no matches.

Run: `flutter test test/features/quest_share_test.dart test/features/quests_screen_test.dart test/features/quest_card_test.dart && flutter analyze`
Expected: PASS, no issues.

```bash
git add -A lib/data lib/providers lib/features/share lib/features/quests/quest_share.dart test/features/quest_share_test.dart
git commit -m "refactor: generic ShareService and widget capture"
```

- [ ] **Step 2: Write the failing achievement share tests**

Create `test/features/achievement_share_test.dart`:
```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/share_service.dart';
import 'package:liferpg/features/achievements/achievement_share.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/share_providers.dart';

import 'achievements_test_support.dart';

class FakeShareService implements ShareService {
  final calls = <(String, Uint8List?)>[];

  @override
  Future<void> share({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
  }) async =>
      calls.add((text, imageBytes));
}

final zosia =
    Character.fromMap('c1', zosiaCharacter(achievements: [achievementMap()]));

Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester, FakeShareService service) async {
  late BuildContext context;
  late WidgetRef ref;
  await tester.pumpWidget(ProviderScope(
    overrides: [shareServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: Consumer(builder: (c, r, _) {
        context = c;
        ref = r;
        return const SizedBox();
      }),
    ),
  ));
  return (context, ref);
}

void main() {
  test('caption keeps the name in the nominative and adds the event', () {
    expect(
      achievementShareCaption('Zosia', zosia.achievements.single),
      'Zosia — odznaka „II miejsce” (Wojewódzki Konkurs Recytatorski)',
    );
  });

  testWidgets('shares a captured card image with the caption', (tester) async {
    final service = FakeShareService();
    final (context, ref) = await pumpHost(tester, service);
    final result =
        shareAchievement(context, ref, zosia, zosia.achievements.single);
    var done = false;
    unawaited(result.whenComplete(() => done = true));
    // Same bounded pump loop as quest_share_test: capture mixes test frames
    // with the real rasterizer.
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(Duration.zero);
      }
    });
    expect(done, isTrue);
    expect(service.calls.single.$1, contains('II miejsce'));
    expect(service.calls.single.$2, isNotEmpty);
  });

  testWidgets('a failed capture falls back to text only', (tester) async {
    final service = FakeShareService();
    final (context, ref) = await pumpHost(tester, service);
    await shareAchievement(
      context,
      ref,
      zosia,
      zosia.achievements.single,
      capture: (context, child, {double width = 360}) =>
          throw StateError('no frame'),
    );
    expect(service.calls.single.$2, isNull);
    expect(service.calls.single.$1, startsWith('Zosia — odznaka'));
  });
}
```

Append to `test/features/achievement_detail_screen_test.dart` inside `main()`:
```dart
  testWidgets('everyone who sees the badge gets a share action', (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen, uid: 'zosia');
    expect(find.byKey(const Key('achievement-share')), findsOneWidget);
  });
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/achievement_share_test.dart test/features/achievement_detail_screen_test.dart`
Expected: FAIL — `achievement_share.dart` missing; no share key.

- [ ] **Step 4: Implement the share card**

Create `lib/features/achievements/achievement_share_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';

/// The image shared for a badge: action-free, fixed-width (see
/// captureWidgetImage), with the character, medal, story and reward.
class AchievementShareCard extends StatelessWidget {
  const AchievementShareCard({
    super.key,
    required this.character,
    required this.achievement,
  });

  final Character character;
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final who = [character.name, if (character.clazz != null) character.clazz!]
        .join(' · ');
    return ParchmentFrame(
      band: 'Odznaka',
      gilded: true,
      footerLabel: 'LifeRPG',
      child: Column(
        children: [
          Text(
            who.toUpperCase(),
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontSize: 11,
              letterSpacing: 3,
              color: crimson,
            ),
          ),
          const SizedBox(height: 8),
          BadgeGlow(child: AchievementBadge.of(a, size: 128)),
          const SizedBox(height: 8),
          Text(
            a.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: inkHeading,
            ),
          ),
          if (a.event != null)
            Text(
              a.event!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: crimson,
              ),
            ),
          if (a.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              '„${a.reason}”',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 14,
                height: 1.35,
                color: inkHeading,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const OrnamentDivider(),
          const SizedBox(height: 10),
          RewardChips(reward: a.reward),
          const SizedBox(height: 10),
          Text(
            formatPolishDate(a.date),
            style: const TextStyle(
              fontFamily: fontBody,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: crimson,
            ),
          ),
        ],
      ),
    );
  }
}
```

Create `lib/features/achievements/achievement_share.dart`:
```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/character.dart';
import '../../providers/share_providers.dart';
import '../share/widget_capture.dart';
import 'achievement_share_card.dart';

typedef WidgetCapture = Future<Uint8List?> Function(
  BuildContext context,
  Widget child, {
  double width,
});

/// Worded so the name stays in the nominative: names can't be declined
/// automatically (`Odznaka dla Zosia` would be wrong). No link -- a badge is
/// only readable by people who can see the character.
String achievementShareCaption(String characterName, Achievement a) =>
    '$characterName — odznaka „${a.title}”'
    '${a.event == null ? '' : ' (${a.event})'}';

/// Shares [achievement] as an image of [AchievementShareCard] plus a caption;
/// a failed capture degrades to the caption alone, as quests do.
Future<void> shareAchievement(
  BuildContext context,
  WidgetRef ref,
  Character character,
  Achievement achievement, {
  WidgetCapture capture = captureWidgetImage,
}) async {
  final service = ref.read(shareServiceProvider);
  Uint8List? imageBytes;
  try {
    imageBytes = await capture(
      context,
      AchievementShareCard(character: character, achievement: achievement),
    );
  } catch (e) {
    debugPrint('Text-only share for achievement ${achievement.id}: $e');
  }
  await service.share(
    text: achievementShareCaption(character.name, achievement),
    imageBytes: imageBytes,
    imageName: 'odznaka-${achievement.id}.png',
  );
}
```

- [ ] **Step 5: Add the share action to the detail screen**

In `lib/features/achievements/achievement_detail_screen.dart` add `import 'achievement_share.dart';` and, as the first entry of the AppBar `actions` list (before the admin block):
```dart
        if (character != null && achievement != null)
          IconButton(
            key: const Key('achievement-share'),
            tooltip: 'Udostępnij',
            icon: const Icon(Icons.share),
            onPressed: () =>
                shareAchievement(context, ref, character, achievement),
          ),
```

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test test/features/ && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/achievements/achievement_share_card.dart lib/features/achievements/achievement_share.dart lib/features/achievements/achievement_detail_screen.dart test/features/achievement_share_test.dart test/features/achievement_detail_screen_test.dart
git commit -m "feat: share an achievement as a card image"
```

---

### Task 10: Notifications and the "Nowa odznaka" dialog

**Files:**
- Create: `lib/data/achievement_notification_repository.dart`, `lib/providers/achievement_notification_providers.dart`, `lib/features/achievements/new_achievement_dialog.dart`, `lib/features/achievements/achievement_celebration_host.dart`
- Modify: `lib/main.dart`
- Test: `test/providers/achievement_notification_providers_test.dart`, `test/features/achievement_celebration_host_test.dart`

**Interfaces:**
- Consumes: `charactersProvider`, `CharacterFeed`, `appUserProvider`, `changeRequestNotificationServiceProvider`, `diffNewIds` (`lib/data/quest_notifications.dart`), `sharedPreferencesProvider`, `rewardParts`, `shareAchievement`, `ParchmentFrame`, `RewardChips`, `BadgeGlow`.
- Produces:
  - `AchievementNotificationRepository(SharedPreferences)`: `Set<String>? loadNotifiedIds(uid)`, `saveNotifiedIds(uid, ids)`, `Set<String>? loadCelebratedIds(uid)`, `saveCelebratedIds(uid, ids)`.
  - `typedef OwnedAchievement = ({Character character, Achievement achievement});`, `List<OwnedAchievement> ownAchievements(CharacterFeed feed, AppUser user)`.
  - `achievementNotificationRepositoryProvider`, `achievementNotificationsProvider` (`Provider<void>`), `celebrationQueueProvider` (`NotifierProvider<CelebrationQueue, List<OwnedAchievement>>`) with `CelebrationQueue.dismiss(String achievementId)`.
  - `Future<void> showNewAchievementDialog(BuildContext context, {required Character character, required Achievement achievement, required VoidCallback onShare})`; keys `new-achievement-share`, `new-achievement-close`.
  - `AchievementCelebrationHost({required Widget child})`.

- [ ] **Step 1: Write the failing provider tests**

Create `test/providers/achievement_notification_providers_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notification_service.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/models/app_user.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/achievement_notification_providers.dart';
import 'package:liferpg/providers/auth_providers.dart';
import 'package:liferpg/providers/change_request_notification_providers.dart';
import 'package:liferpg/providers/character_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/achievements_test_support.dart';

class FakeNotificationService implements ChangeRequestNotificationService {
  final shown = <String, String>{};

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) async =>
      shown[id] = '$title|$body';
}

Future<ProviderContainer> containerFor(
  FakeFirebaseFirestore db,
  FakeNotificationService service, {
  String uid = 'zosia',
  bool resetPrefs = true,
}) async {
  if (resetPrefs) SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: '$uid@example.com'),
    )),
    sharedPreferencesProvider
        .overrideWithValue(await SharedPreferences.getInstance()),
    changeRequestNotificationServiceProvider.overrideWithValue(service),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> settle(ProviderContainer container) async {
  await container.read(charactersProvider.future);
  await Future<void>.delayed(Duration.zero);
}

Future<void> addBadge(FakeFirebaseFirestore db, Map<String, dynamic> badge) async {
  final data = await characterData(db);
  await db.collection('characters').doc('c1').update({
    'achievements': [...(data['achievements'] as List? ?? []), badge],
  });
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('existing badges seed silently; a new one notifies the owner', () async {
    final db = await seedWorld(achievements: [achievementMap(id: 'old')]);
    final service = FakeNotificationService();
    final container = await containerFor(db, service);
    container.listen(achievementNotificationsProvider, (_, _) {});
    await settle(container);
    expect(service.shown, isEmpty);

    await addBadge(db, achievementMap(id: 'new', title: 'Koncert jesienny'));
    expect(service.shown['achievement_new'],
        'Nowa odznaka: Koncert jesienny|Zosia · +150 XP, +50 zł, Recytacja +1, +2 dni elektroniki');
  });

  test('an admin is not notified about someone else\'s character', () async {
    final db = await seedWorld();
    final service = FakeNotificationService();
    final container = await containerFor(db, service, uid: 'admin');
    container.listen(achievementNotificationsProvider, (_, _) {});
    await settle(container);
    await addBadge(db, achievementMap(id: 'new'));
    expect(service.shown, isEmpty);
  });

  test('a cache-only first snapshot neither notifies nor seeds', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = FakeNotificationService();
    final cached = CharacterFeed(
      characters: [
        Character.fromMap('c1', zosiaCharacter(achievements: [achievementMap()]))
      ],
      isFromCache: true,
      hasPendingWrites: false,
    );
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      changeRequestNotificationServiceProvider.overrideWithValue(service),
      appUserProvider.overrideWith((ref) => Stream.value(const AppUser(
            uid: 'zosia', name: 'Zosia', email: 'zosia@example.com',
            admin: false, readOnlyOthers: false))),
      charactersProvider.overrideWith((ref) => Stream.value(cached)),
    ]);
    addTearDown(container.dispose);
    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);
    container.listen(achievementNotificationsProvider, (_, _) {});
    container.listen(celebrationQueueProvider, (_, _) {});
    await container.read(charactersProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, isEmpty);
    expect(container.read(celebrationQueueProvider), isEmpty);
    final repo = container.read(achievementNotificationRepositoryProvider);
    expect(repo.loadNotifiedIds('zosia'), isNull);
    expect(repo.loadCelebratedIds('zosia'), isNull);
  });

  test('celebration queue: new badge queued, dismiss persists, undismissed survives restart',
      () async {
    final db = await seedWorld(achievements: [achievementMap(id: 'old')]);
    final service = FakeNotificationService();
    final container = await containerFor(db, service);
    container.listen(celebrationQueueProvider, (_, _) {});
    await settle(container);
    expect(container.read(celebrationQueueProvider), isEmpty);

    // Distinct awardedAt: the queue is ordered oldest first.
    await addBadge(db, achievementMap(id: 'b1', awardedAt: DateTime(2026, 10, 1)));
    await addBadge(db, achievementMap(id: 'b2', awardedAt: DateTime(2026, 10, 2)));
    expect(container.read(celebrationQueueProvider).map((o) => o.achievement.id),
        ['b1', 'b2']);

    container.read(celebrationQueueProvider.notifier).dismiss('b1');
    expect(container.read(celebrationQueueProvider).map((o) => o.achievement.id),
        ['b2']);

    // "Restart": a second container over the same prefs (the first is
    // disposed by its tearDown).
    final restarted = await containerFor(db, service, resetPrefs: false);
    restarted.listen(celebrationQueueProvider, (_, _) {});
    await settle(restarted);
    expect(restarted.read(celebrationQueueProvider).map((o) => o.achievement.id),
        ['b2']);
  });
}
```

- [ ] **Step 2: Write the failing host test**

Create `test/features/achievement_celebration_host_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_celebration_host.dart';

import 'achievements_test_support.dart';

void main() {
  testWidgets('a badge awarded after launch pops the dialog once',
      (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
      tester,
      db,
      const AchievementCelebrationHost(child: Scaffold(body: Text('dom'))),
      uid: 'zosia',
    );
    expect(find.text('Koncert jesienny'), findsNothing);

    await db.collection('characters').doc('c1').update({
      'achievements': [achievementMap(id: 'n1', title: 'Koncert jesienny')],
    });
    await tester.pumpAndSettle();
    expect(find.text('✦ NOWA ODZNAKA ✦'), findsOneWidget);
    expect(find.text('Koncert jesienny'), findsOneWidget);
    expect(find.text('+150 XP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-achievement-close')));
    await tester.pumpAndSettle();
    expect(find.text('✦ NOWA ODZNAKA ✦'), findsNothing);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/providers/achievement_notification_providers_test.dart test/features/achievement_celebration_host_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 4: Implement the repository**

Create `lib/data/achievement_notification_repository.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

/// On-device, per-uid baselines for badge announcements, same shape as
/// QuestNotificationRepository: a `null` load means "no baseline yet", so
/// the caller seeds silently instead of announcing badges that already
/// existed. Two sets: tray notifications sent, and "Nowa odznaka" dialogs
/// actually dismissed -- a badge leaves the dialog queue only when its
/// dialog closes, so a dialog is never lost to the app being killed first.
class AchievementNotificationRepository {
  AchievementNotificationRepository(this._prefs);

  final SharedPreferences _prefs;

  String _notifiedKey(String uid) => 'notified_achievements_$uid';
  String _celebratedKey(String uid) => 'celebrated_achievements_$uid';

  Set<String>? loadNotifiedIds(String uid) =>
      _prefs.getStringList(_notifiedKey(uid))?.toSet();
  Future<void> saveNotifiedIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_notifiedKey(uid), ids.toList());

  Set<String>? loadCelebratedIds(String uid) =>
      _prefs.getStringList(_celebratedKey(uid))?.toSet();
  Future<void> saveCelebratedIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_celebratedKey(uid), ids.toList());
}
```

- [ ] **Step 5: Implement the providers**

Create `lib/providers/achievement_notification_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/achievement_notification_repository.dart';
import '../data/character_repository.dart';
import '../data/quest_notifications.dart';
import '../data/shared_preferences_provider.dart';
import '../models/achievement.dart';
import '../models/achievement_formatting.dart';
import '../models/app_user.dart';
import '../models/character.dart';
import 'auth_providers.dart';
import 'change_request_notification_providers.dart';
import 'character_providers.dart';

typedef OwnedAchievement = ({Character character, Achievement achievement});

final achievementNotificationRepositoryProvider =
    Provider<AchievementNotificationRepository>(
  (ref) =>
      AchievementNotificationRepository(ref.watch(sharedPreferencesProvider)),
);

/// Badges on the signed-in user's own characters (by email, like
/// HomeScreen's `ownsACharacter`) -- an admin awarding someone else's
/// character is never told about it; awarding their own, they are.
List<OwnedAchievement> ownAchievements(CharacterFeed feed, AppUser user) {
  final email = user.email.toLowerCase();
  return [
    for (final c in feed.characters)
      if (c.email.toLowerCase() == email)
        for (final a in c.achievements) (character: c, achievement: a),
  ];
}

/// Watched once from AuthGate, alongside the quest / change-request ones.
/// Rides the roster stream the home screen already holds -- no new listener.
final achievementNotificationsProvider = Provider<void>((ref) {
  ref.listen(charactersProvider, (previous, next) {
    final feed = next.value;
    final user = ref.read(appUserProvider).value;
    if (feed == null || user == null) return;
    final repo = ref.read(achievementNotificationRepositoryProvider);
    final previously = repo.loadNotifiedIds(user.uid);
    // With no baseline, a cache-only snapshot may be empty or stale: seeding
    // from it would announce every existing badge once the server answers.
    if (previously == null && feed.isFromCache) return;
    final diff = diffNewIds(
      items: ownAchievements(feed, user),
      idOf: (OwnedAchievement o) => o.achievement.id,
      previouslyNotified: previously,
    );
    // A cache snapshot can lack badges the server still has; don't forget
    // them on its account.
    repo.saveNotifiedIds(
      user.uid,
      feed.isFromCache ? {...?previously, ...diff.notifiedIds} : diff.notifiedIds,
    );
    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final o in diff.toNotify) {
      final parts = rewardParts(o.achievement.reward);
      service.show(
        id: 'achievement_${o.achievement.id}',
        title: 'Nowa odznaka: ${o.achievement.title}',
        body: parts.isEmpty
            ? o.character.name
            : '${o.character.name} · ${parts.join(', ')}',
        payload: 'achievement',
      );
    }
  });
});

/// Own badges whose "Nowa odznaka" dialog hasn't been dismissed yet,
/// oldest first. Same baseline rules as the notifications above.
class CelebrationQueue extends Notifier<List<OwnedAchievement>> {
  @override
  List<OwnedAchievement> build() {
    final feed = ref.watch(charactersProvider).value;
    final user = ref.watch(appUserProvider).value;
    if (feed == null || user == null) return const [];
    final repo = ref.watch(achievementNotificationRepositoryProvider);
    final own = ownAchievements(feed, user);
    final currentIds = {for (final o in own) o.achievement.id};
    final celebrated = repo.loadCelebratedIds(user.uid);
    if (celebrated == null) {
      if (!feed.isFromCache) repo.saveCelebratedIds(user.uid, currentIds);
      return const [];
    }
    // Forget revoked badges, but only on a server snapshot -- a partial
    // cache must not make an old badge look new later.
    if (!feed.isFromCache) {
      final kept = celebrated.intersection(currentIds);
      if (kept.length != celebrated.length) {
        repo.saveCelebratedIds(user.uid, kept);
      }
    }
    return own.where((o) => !celebrated.contains(o.achievement.id)).toList()
      ..sort((a, b) => a.achievement.awardedAt.compareTo(b.achievement.awardedAt));
  }

  void dismiss(String achievementId) {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final repo = ref.read(achievementNotificationRepositoryProvider);
    repo.saveCelebratedIds(
      user.uid,
      {...?repo.loadCelebratedIds(user.uid), achievementId},
    );
    state = [
      for (final o in state)
        if (o.achievement.id != achievementId) o,
    ];
  }
}

final celebrationQueueProvider =
    NotifierProvider<CelebrationQueue, List<OwnedAchievement>>(
  CelebrationQueue.new,
);
```

- [ ] **Step 6: Implement the dialog and its host**

Create `lib/features/achievements/new_achievement_dialog.dart`:
```dart
import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';

const TextStyle _button = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 12,
  letterSpacing: 2,
);

/// "Nowa odznaka": shown once per badge to its owner (see
/// AchievementCelebrationHost). Completes when closed by any means.
Future<void> showNewAchievementDialog(
  BuildContext context, {
  required Character character,
  required Achievement achievement,
  required VoidCallback onShare,
}) {
  final a = achievement;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: ParchmentFrame(
          band: 'Nowa odznaka',
          gilded: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeGlow(child: AchievementBadge.of(a, size: 132)),
              const SizedBox(height: 8),
              Text(
                'Odznaka ${tierAdjective(a.tier)}'.toUpperCase(),
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 10,
                  letterSpacing: 3,
                  color: crimson,
                ),
              ),
              Text(
                a.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: inkHeading,
                ),
              ),
              if (a.event != null)
                Text(
                  a.event!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: fontBody,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: crimson,
                  ),
                ),
              if (rewardParts(a.reward).isNotEmpty) ...[
                const SizedBox(height: 12),
                const LabelledDivider(label: 'Otrzymujesz'),
                const SizedBox(height: 8),
                RewardChips(reward: a.reward),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('new-achievement-share'),
                      onPressed: onShare,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: crimson,
                        side: const BorderSide(color: crimson),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text('Udostępnij'.toUpperCase(), style: _button),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('new-achievement-close'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: crimson,
                        foregroundColor: parchmentLight,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text('Wspaniale'.toUpperCase(), style: _button),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

Create `lib/features/achievements/achievement_celebration_host.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/achievement_notification_providers.dart';
import 'achievement_share.dart';
import 'new_achievement_dialog.dart';

/// Wraps the signed-in home: whenever the celebration queue has a badge,
/// shows its "Nowa odznaka" dialog, one at a time, marking each dismissed
/// only once its dialog closes.
class AchievementCelebrationHost extends ConsumerStatefulWidget {
  const AchievementCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AchievementCelebrationHost> createState() =>
      _AchievementCelebrationHostState();
}

class _AchievementCelebrationHostState
    extends ConsumerState<AchievementCelebrationHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
  }

  Future<void> _showNext() async {
    if (_showing || !mounted) return;
    final queue = ref.read(celebrationQueueProvider);
    if (queue.isEmpty) return;
    _showing = true;
    final item = queue.first;
    await showNewAchievementDialog(
      context,
      character: item.character,
      achievement: item.achievement,
      onShare: () =>
          shareAchievement(context, ref, item.character, item.achievement),
    );
    if (!mounted) return;
    ref.read(celebrationQueueProvider.notifier).dismiss(item.achievement.id);
    _showing = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(celebrationQueueProvider, (_, _) => _showNext());
    return widget.child;
  }
}
```

- [ ] **Step 7: Wire into `main.dart`**

In `lib/main.dart` add imports `features/achievements/achievement_celebration_host.dart` and `providers/achievement_notification_providers.dart`. In `AuthGate.build`, after `ref.watch(questNotificationsProvider);` add `ref.watch(achievementNotificationsProvider);`, and change the returned widget to:
```dart
            return const _PendingQuestLinkGate(
              child: AchievementCelebrationHost(child: HomeScreen()),
            );
```
(The `'achievement'` notification payload needs no case in `_openNotificationTarget`: opening the app is enough — the dialog appears on its own.)

- [ ] **Step 8: Run the full suite and analyze**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 9: Commit**

```bash
git add lib/data/achievement_notification_repository.dart lib/providers/achievement_notification_providers.dart lib/features/achievements/new_achievement_dialog.dart lib/features/achievements/achievement_celebration_host.dart lib/main.dart test/providers/achievement_notification_providers_test.dart test/features/achievement_celebration_host_test.dart
git commit -m "feat: notify owners of new achievements and celebrate them in-app"
```

---

### Task 11: Documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Data model**

In `CLAUDE.md` → Firestore Data Model → `characters/{id}` code block, add a line:
```
achievements: [{ id, title, event?, reason?, date: 'YYYY-MM-DD', emblem, place?, tier, reward: { current_xp?, gold?, traits?: [{name, value}], electronics_days? }, awardedBy, awardedByName, awardedAt }]  (optional)
```
and below the electronics bullet add:
```markdown
- **Achievements live inside the character document** (not a collection), so
  their visibility and write rules are the character's — `firestore.rules`
  has no achievement-specific rule. Entries are written only by
  `AchievementRepository` (`award` / `edit` / `revoke`, each a
  `runTransaction` on the admin's client that changes the list and applies
  the reward in one update); **`Character.toMap()` omits `achievements`**
  exactly like `electronics`. `awardedAt` is a client `Timestamp` because
  Firestore rejects `serverTimestamp()` inside arrays. `award` is a no-op for
  an id already present (the form generates its id once), `revoke` for an id
  already gone. Reward deltas reuse `applyCharacterDeltas`
  (`lib/models/character_deltas.dart`, shared with change-request accept);
  revoke applies the negated reward, so XP / gold / trait may go negative,
  while electronics days go through `ElectronicsDays.addDays` and clamp at
  0. A badge's reward cannot be edited — `edit` changes presentation only.
  `AchievementReward` is deliberately not part of `ChangeSet`, so an
  `electronics_days` key can never ride in an ordinary change request.
```

- [ ] **Step 2: Key Behaviors**

Add after the **Electronics days** entry:
```markdown
- **Achievements** ("Odznaki", `lib/features/achievements/`): admin-only
  awards with an individually chosen reward (XP / gold / one trait /
  electronics days). Each badge is a medal (`AchievementBadge`): the tier
  (złoto / srebro / brąz / rubin) is the ring's metal, the emblem (place
  I–III, puchar, nuta, szczyt, księga, gwiazda) sits on the disk. The card's
  **Odznaki** section (`AchievementsSection`, below Cechy) shows the four
  newest with a `NOWA` chip for badges under 7 days old; players and
  `readOnlyOthers` see it only when the character has a badge, admins always
  (with **PRZYZNAJ ODZNAKĘ** when empty). Gallery (`AchievementsScreen`,
  admin `+`), detail (`AchievementDetailScreen`: share for everyone who can
  see it; admin **Edytuj** and **Usuń**, the latter confirming exactly what
  will be taken back), and the award / edit form
  (`AwardAchievementScreen`; picking a place pre-sets emblem, tier and title;
  the date is a `RRRR-MM-DD` field because the app ships no Polish Material
  localizations). There are no categories and no player requests for badges.
- **Achievement notifications**: the owner (by email) gets a tray
  notification and an in-app **Nowa odznaka** dialog
  (`AchievementCelebrationHost` around `HomeScreen`) for each new badge,
  from `lib/providers/achievement_notification_providers.dart` riding the
  existing character stream. `AchievementNotificationRepository` keeps two
  per-uid sets — notified, and celebrated (added only when the dialog
  closes, so a dialog survives the app being killed). A first snapshot with
  no baseline seeds silently, and a **cache-only** first snapshot neither
  seeds nor announces. Revoking sends nothing.
```

In the **Quest sharing** entry replace `share_plus`, behind the `QuestShareService` seam` with `share_plus`, behind the generic `ShareService` seam (`shareServiceProvider`), with the offscreen capture in `lib/features/share/widget_capture.dart` shared with achievement sharing` and append: `Achievements share the same way (`shareAchievement`, `AchievementShareCard`) but with **no link** — a badge is only readable by people who can see the character — and a caption that keeps the name in the nominative (`Zosia — odznaka „II miejsce” (…)`).`

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document achievements"
```

- [ ] **Step 4: Final verification**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests pass.
