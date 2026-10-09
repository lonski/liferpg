# Electronics Days Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Dni elektroniki" section to every character card. The section banks one day per full local calendar day. A player spends a day through an admin-approved change request, and an admin can spend one directly or set the counter by hand.

**Architecture:** The counter is a stored number with lazy accrual: `{days, as_of, claimed}` on the character. Readers add the full days elapsed since `as_of`, and every write settles that accrual first. All arithmetic lives in a pure `ElectronicsDays` value class. Writes go through transactional repository methods. The card renders a presentational `ElectronicsSection` fed by a Riverpod-aware `ElectronicsPanel`.

**Tech Stack:** Flutter/Dart, Riverpod 3, cloud_firestore, fake_cloud_firestore, firebase_auth_mocks, Firestore rules emulator tests (Node `node:test` + `@firebase/rules-unit-testing`).

**Spec:** `docs/superpowers/specs/2026-10-09-electronics-days-design.md`

## Global Constraints

- UI copy is Polish, verbatim from the spec. String literals keep normal casing, and labels are `.toUpperCase()`d at the point of use, as the rest of the card does.
- Firestore field names are snake_case (`electronics`, `days`, `as_of`, `claimed`, `electronics_claim`). Dart names are camelCase.
- Colours are `const Color(0xAARRGGBB)` tokens from `lib/theme/app_theme.dart`. Never introduce raw colours that aren't already tokens there; reuse `crimson`, `gold`, `inkHeading`, `crimsonFaint`, `crimsonBorder`, `crimsonBorderStrong`, `crimsonBorderFaint`, `goldGlyph`, `ornamentInk`, `parchmentLight`, `crimsonBgFaint`.
- Never touch `FirebaseFirestore.instance`, `FirebaseAuth.instance` or `SharedPreferences.getInstance()` outside their providers. Never call `DateTime.now()` directly in new code: read `clockProvider`, or take an injected `DateTime Function()` in a repository constructor.
- Riverpod 3: no `valueOrNull`, use `.value`. Attach a listener before awaiting a `StreamProvider`'s `.future` in a container test.
- Days are `int`s counting days since 1970-01-01, built via `dayOf(DateTime)`. Strings `'YYYY-MM-DD'` appear only at the Firestore boundary.
- `kElectronicsDaysEpoch = 20736`, which is 2026-10-10.
- Run `flutter analyze` and `flutter test` (whole suite) green before every commit. End commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Work on branch `feature/electronics-days`.

## Review Focus

- **Late approval across midnight:** a claim tapped on day D and accepted on D+1 or later must leave the counter as if D had been claimed on D (−2 relative to the settled value). This is pinned in Task 1 and Task 3.
- **Double application:** accepting a claim for a date already in `claimed`, for example after an admin direct claim the same day, must not change the counter. This is pinned in Task 1 and Task 3.
- **Edit screen racing a claim:** saving the edit screen must never overwrite `electronics`. `Character.toMap()` excludes it, which is pinned in Task 2 and Task 7.
- **Midnight while the app is open:** the panel's one-minute ticker must roll the count over without a relaunch. This is pinned in Task 6.
- **Malformed legacy data** (`days: "7"`, garbage `as_of`, non-string `claimed` entries) must parse tolerantly and never throw. This is pinned in Task 1.

---

### Task 1: `ElectronicsDays` value class and day helpers

**Files:**
- Create: `lib/models/electronics_days.dart`
- Test: `test/models/electronics_days_test.dart`

**Interfaces:**
- Produces:
  - `int dayOf(DateTime t)`
  - `String formatDay(int day)`
  - `int? parseDay(Object? v)`
  - `double dayFraction(DateTime now)`
  - `const int kElectronicsDaysEpoch`
  - `enum ElectronicsCardState { charging, pending, claimed, empty }`
  - `class ElectronicsDays`, with:
    - `const ElectronicsDays({int days = 0, int asOf = kElectronicsDaysEpoch, List<int> claimed = const []})`
    - `factory ElectronicsDays.fromMap(Object? raw)`
    - `Map<String, dynamic> toMap()`
    - `int accrued(int today)`
    - `int available(int today)`
    - `bool isClaimed(int day)`
    - `ElectronicsDays settle(int today)`
    - `ElectronicsDays withValue(int value, int today)`
    - `ElectronicsDays applyClaim(int day, int today)`
    - `ElectronicsCardState stateFor(int today, {required bool hasPendingClaim})`

- [ ] **Step 1: Write the failing tests**

```dart
// test/models/electronics_days_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/electronics_days.dart';

int d(String s) => parseDay(s)!;

void main() {
  group('day helpers', () {
    test('format/parse round-trip', () {
      expect(formatDay(d('2026-10-09')), '2026-10-09');
      expect(formatDay(kElectronicsDaysEpoch), '2026-10-10');
    });

    test('parseDay rejects malformed input', () {
      expect(parseDay('2026-02-30'), isNull);
      expect(parseDay('abc'), isNull);
      expect(parseDay('2026-1-1'), isNull);
      expect(parseDay(42), isNull);
      expect(parseDay(null), isNull);
    });

    test('dayOf uses the local calendar date and survives DST', () {
      // 2026-10-25 is the EU DST end; a 25-hour local day.
      expect(dayOf(DateTime(2026, 10, 25, 0, 30)),
          dayOf(DateTime(2026, 10, 25, 23, 30)));
      expect(dayOf(DateTime(2026, 10, 26, 0, 1)) - dayOf(DateTime(2026, 10, 25, 23, 59)), 1);
      expect(formatDay(dayOf(DateTime(2026, 10, 9, 23, 59))), '2026-10-09');
    });

    test('dayFraction is the elapsed share of the local day', () {
      expect(dayFraction(DateTime(2026, 10, 9)), 0.0);
      expect(dayFraction(DateTime(2026, 10, 9, 12)), closeTo(0.5, 0.0001));
    });
  });

  group('accrual', () {
    test('a fresh character starts at 0 on the epoch and earns a day per full day', () {
      const e = ElectronicsDays();
      expect(e.available(kElectronicsDaysEpoch - 5), 0);
      expect(e.available(kElectronicsDaysEpoch), 0);
      expect(e.available(kElectronicsDaysEpoch + 3), 3);
    });

    test('adds full days since as_of to the stored count', () {
      final e = ElectronicsDays(days: 5, asOf: d('2026-10-20'));
      expect(e.available(d('2026-10-23')), 8);
    });

    test('as_of in the future accrues nothing', () {
      final e = ElectronicsDays(days: 4, asOf: d('2026-10-23'));
      expect(e.accrued(d('2026-10-22')), 0);
      expect(e.available(d('2026-10-22')), 4);
    });

    test('settle folds accrual into days without changing available', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final s = e.settle(d('2026-10-22'));
      expect(s.days, 5);
      expect(s.asOf, d('2026-10-22'));
      expect(s.available(d('2026-10-24')), e.available(d('2026-10-24')));
    });
  });

  group('writes', () {
    test('withValue sets today\'s value and clamps at 0', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final v = e.withValue(9, d('2026-10-22'));
      expect(v.available(d('2026-10-22')), 9);
      expect(v.available(d('2026-10-23')), 10);
      expect(e.withValue(-4, d('2026-10-22')).available(d('2026-10-22')), 0);
    });

    test('claiming today costs one and today never accrues', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final c = e.applyClaim(d('2026-10-22'), d('2026-10-22'));
      expect(c.available(d('2026-10-22')), 4); // 5 settled - 1
      expect(c.available(d('2026-10-23')), 4); // 22nd not accrued
      expect(c.available(d('2026-10-24')), 5);
      expect(c.isClaimed(d('2026-10-22')), isTrue);
    });

    test('a late approval takes back the day that already accrued', () {
      // Tapped on the 21st, accepted on the 22nd.
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final c = e.applyClaim(d('2026-10-21'), d('2026-10-22'));
      expect(c.available(d('2026-10-22')), 3); // 3 + 20th, 21st claimed: -1, not accrued
      expect(c.available(d('2026-10-23')), 4);
    });

    test('claiming an already-claimed date is a no-op', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'))
          .applyClaim(d('2026-10-22'), d('2026-10-22'));
      final again = e.applyClaim(d('2026-10-22'), d('2026-10-23'));
      expect(again.days, e.days);
      expect(again.asOf, e.asOf);
      expect(again.claimed, e.claimed);
    });

    test('claiming at zero clamps at zero', () {
      final e = ElectronicsDays(days: 0, asOf: d('2026-10-22'));
      expect(e.applyClaim(d('2026-10-22'), d('2026-10-22')).available(d('2026-10-22')), 0);
    });

    test('keeps only the 31 most recent claimed dates', () {
      var e = ElectronicsDays(days: 100, asOf: d('2026-10-01'));
      for (var i = 0; i < 40; i++) {
        final day = d('2026-10-01') + i;
        e = e.applyClaim(day, day);
      }
      expect(e.claimed, hasLength(31));
      expect(e.claimed.first, d('2026-10-01') + 9);
      expect(e.claimed.last, d('2026-10-01') + 39);
    });
  });

  group('map', () {
    test('missing or non-map reads as the default', () {
      expect(ElectronicsDays.fromMap(null).available(kElectronicsDaysEpoch + 2), 2);
      expect(ElectronicsDays.fromMap('x').days, 0);
    });

    test('tolerates stringly and garbage values', () {
      final e = ElectronicsDays.fromMap({
        'days': '7',
        'as_of': 'garbage',
        'claimed': ['2026-10-11', 5, 'x', '2026-10-11'],
      });
      expect(e.days, 7);
      expect(e.asOf, kElectronicsDaysEpoch);
      expect(e.claimed, [d('2026-10-11')]);
    });

    test('toMap round-trips', () {
      final e = ElectronicsDays(days: 4, asOf: d('2026-10-23'), claimed: [d('2026-10-22')]);
      expect(e.toMap(), {'days': 4, 'as_of': '2026-10-23', 'claimed': ['2026-10-22']});
      final back = ElectronicsDays.fromMap(e.toMap());
      expect(back.days, 4);
      expect(back.asOf, d('2026-10-23'));
      expect(back.claimed, [d('2026-10-22')]);
    });
  });

  group('stateFor', () {
    final today = d('2026-10-22');
    test('claimed wins over everything', () {
      final e = ElectronicsDays(days: 3, asOf: today, claimed: [today]);
      expect(e.stateFor(today, hasPendingClaim: true), ElectronicsCardState.claimed);
    });
    test('pending wins over empty', () {
      final e = ElectronicsDays(days: 0, asOf: today);
      expect(e.stateFor(today, hasPendingClaim: true), ElectronicsCardState.pending);
    });
    test('empty at zero, charging otherwise', () {
      expect(ElectronicsDays(days: 0, asOf: today).stateFor(today, hasPendingClaim: false),
          ElectronicsCardState.empty);
      expect(ElectronicsDays(days: 2, asOf: today).stateFor(today, hasPendingClaim: false),
          ElectronicsCardState.charging);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/electronics_days_test.dart`
Expected: compile failure, `electronics_days.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/models/electronics_days.dart
import 'dart:math' as math;

/// Electronics days are counted in whole local calendar days. A "day" here is
/// a plain int -- days since 1970-01-01 -- built from the *local* date via
/// `DateTime.utc`, so a DST change can never produce a 23- or 25-hour day and
/// the value stays `const`-friendly. Strings ('YYYY-MM-DD') only exist at the
/// Firestore boundary.
int dayOf(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// 2026-10-10, the first full day after the feature shipped. A character with
/// no `electronics` map counts from 0 here.
const int kElectronicsDaysEpoch = 20736;

final RegExp _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

String formatDay(int day) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(d.year, 4)}-${pad(d.month, 2)}-${pad(d.day, 2)}';
}

int? parseDay(Object? v) {
  if (v is! String) return null;
  final m = _dayPattern.firstMatch(v.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final dd = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, dd);
  // DateTime normalises 2026-02-30 to March; reject instead of guessing.
  if (date.year != y || date.month != mo || date.day != dd) return null;
  return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// How much of the local calendar day containing [now] has elapsed, 0.0-1.0.
double dayFraction(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day + 1);
  final f = now.difference(start).inSeconds / end.difference(start).inSeconds;
  return f.clamp(0.0, 1.0).toDouble();
}

/// The four card states, in the order the spec checks them: claimed, pending,
/// empty, charging.
enum ElectronicsCardState { charging, pending, claimed, empty }

/// The `electronics` map on a character: a banked count as of the start of
/// [asOf], plus recently claimed days. Accrual is lazy -- nothing ticks at
/// midnight; readers add the full days since [asOf], and every write
/// [settle]s that accrual into [days] first.
class ElectronicsDays {
  const ElectronicsDays({
    this.days = 0,
    this.asOf = kElectronicsDaysEpoch,
    this.claimed = const [],
  });

  static const int maxClaimed = 31;

  final int days;
  final int asOf;

  /// Sorted ascending, deduplicated, at most [maxClaimed] entries.
  final List<int> claimed;

  /// Tolerant in the style of `Character.fromMap`: never throws on legacy or
  /// hand-edited data.
  factory ElectronicsDays.fromMap(Object? raw) {
    if (raw is! Map) return const ElectronicsDays();
    final rawDays = raw['days'];
    final days = rawDays is num
        ? rawDays.toInt()
        : rawDays is String
            ? (num.tryParse(rawDays.trim())?.toInt() ?? 0)
            : 0;
    final rawClaimed = raw['claimed'];
    final claimed = rawClaimed is List
        ? (rawClaimed.map(parseDay).whereType<int>().toSet().toList()..sort())
        : <int>[];
    return ElectronicsDays(
      days: days,
      asOf: parseDay(raw['as_of']) ?? kElectronicsDaysEpoch,
      claimed: claimed,
    );
  }

  Map<String, dynamic> toMap() => {
        'days': days,
        'as_of': formatDay(asOf),
        'claimed': [for (final d in claimed) formatDay(d)],
      };

  /// Full days in [asOf, today). Zero when [asOf] is today or later.
  int accrued(int today) => math.max(0, today - asOf);

  int available(int today) => days + accrued(today);

  bool isClaimed(int day) => claimed.contains(day);

  ElectronicsDays settle(int today) => ElectronicsDays(
        days: available(today),
        asOf: math.max(asOf, today),
        claimed: claimed,
      );

  /// An admin's hand-set value: what [available] reads today.
  ElectronicsDays withValue(int value, int today) => ElectronicsDays(
        days: math.max(0, value),
        asOf: math.max(asOf, today),
        claimed: claimed,
      );

  /// Spends [day]: costs one, and [day] itself never adds one. A [day] that
  /// already passed (late approval) has accrued, so it is taken back too.
  /// Claiming a date already in [claimed] changes nothing.
  ElectronicsDays applyClaim(int day, int today) {
    if (isClaimed(day)) return this;
    final settled = settle(today);
    var nextDays = settled.days - 1;
    var nextAsOf = settled.asOf;
    if (day < today) {
      nextDays -= 1;
    } else {
      nextAsOf = math.max(nextAsOf, day + 1);
    }
    final all = [...claimed, day]..sort();
    final trimmed =
        all.length > maxClaimed ? all.sublist(all.length - maxClaimed) : all;
    return ElectronicsDays(
      days: math.max(0, nextDays),
      asOf: nextAsOf,
      claimed: trimmed,
    );
  }

  ElectronicsCardState stateFor(int today, {required bool hasPendingClaim}) {
    if (isClaimed(today)) return ElectronicsCardState.claimed;
    if (hasPendingClaim) return ElectronicsCardState.pending;
    if (available(today) <= 0) return ElectronicsCardState.empty;
    return ElectronicsCardState.charging;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/electronics_days_test.dart`
Expected: all PASS. Then run `flutter analyze` and expect no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/models/electronics_days.dart test/models/electronics_days_test.dart
git commit -m "feat: ElectronicsDays value class with lazy accrual

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Character, ChangeSet and request formatting

**Files:**
- Modify: `lib/models/character.dart` (field, `fromMap`, `copyWith`, doc on `toMap`)
- Modify: `lib/models/change_request.dart` (`ChangeSet.electronicsClaim`)
- Modify: `lib/features/requests/change_request_formatting.dart` (`changeSetLines`)
- Test: `test/models/character_test.dart`, `test/models/change_request_test.dart`, create `test/features/change_request_formatting_test.dart`

**Interfaces:**
- Consumes: `ElectronicsDays`, `ElectronicsDays.fromMap` (Task 1)
- Produces:
  - `Character.electronics` (`ElectronicsDays`, defaults to `const ElectronicsDays()`); `Character.toMap()` does **not** contain `'electronics'`
  - `ChangeSet({num? currentXp, num? gold, List<TraitChange> traits = const [], String? electronicsClaim})`, with `ChangeSet.electronicsClaim` (`String?`, Firestore key `electronics_claim`)
  - `changeSetLines` emits `'Dzień z elektroniką: <date>'`

- [ ] **Step 1: Write the failing tests**

Append to `test/models/character_test.dart` inside `main()`:

```dart
  test('parses the electronics map', () {
    final c = Character.fromMap('c1', {
      'name': 'Ala',
      'email': 'a@example.com',
      'electronics': {'days': 4, 'as_of': '2026-10-23', 'claimed': ['2026-10-22']},
    });
    expect(c.electronics.days, 4);
    expect(formatDay(c.electronics.asOf), '2026-10-23');
  });

  test('a character without electronics gets the default', () {
    final c = Character.fromMap('c1', {'name': 'Ala', 'email': 'a@example.com'});
    expect(c.electronics.days, 0);
    expect(c.electronics.asOf, kElectronicsDaysEpoch);
  });

  test('toMap never writes electronics, so edit-screen saves cannot clobber it', () {
    final c = Character.fromMap('c1', {
      'name': 'Ala',
      'email': 'a@example.com',
      'electronics': {'days': 4, 'as_of': '2026-10-23'},
    });
    expect(c.toMap().containsKey('electronics'), isFalse);
    expect(c.copyWith(level: 2).electronics.days, 4);
  });
```
(add `import 'package:liferpg/models/electronics_days.dart';` at the top)

Append to `test/models/change_request_test.dart` inside `main()`:

```dart
  test('ChangeSet round-trips electronics_claim and counts it as non-empty', () {
    final s = ChangeSet.fromMap({'electronics_claim': '2026-10-22'});
    expect(s.electronicsClaim, '2026-10-22');
    expect(s.isEmpty, isFalse);
    expect(s.toMap(), {'electronics_claim': '2026-10-22'});
    expect(const ChangeSet().toMap().containsKey('electronics_claim'), isFalse);
  });
```

Create `test/features/change_request_formatting_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/requests/change_request_formatting.dart';
import 'package:liferpg/models/change_request.dart';

void main() {
  test('an electronics claim renders as one line', () {
    expect(
      changeSetLines(const ChangeSet(electronicsClaim: '2026-10-22')),
      ['Dzień z elektroniką: 2026-10-22'],
    );
  });

  test('ordinary deltas still render', () {
    expect(changeSetLines(const ChangeSet(currentXp: 50, gold: -10)),
        ['XP: +50', 'Złoto: -10']);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/character_test.dart test/models/change_request_test.dart test/features/change_request_formatting_test.dart`
Expected: compile errors, because `electronics` and `electronicsClaim` are undefined.

- [ ] **Step 3: Implement**

`lib/models/character.dart`:
- add `import 'electronics_days.dart';`
- constructor param `this.electronics = const ElectronicsDays(),`
- field `final ElectronicsDays electronics;` with the doc comment `/// See ElectronicsDays. Written only by CharacterRepository's transactional electronics methods and the change-request accept transaction -- never by toMap().`
- in `fromMap`: `electronics: ElectronicsDays.fromMap(data['electronics']),`
- in `copyWith`'s returned `Character(...)`: `electronics: electronics,`
- above `toMap()` add the comment `// Deliberately omits `electronics`: the edit screen saves via update(toMap()), and including a snapshot of the counter here would overwrite a claim accepted while the screen was open.`

`lib/models/change_request.dart`, in `ChangeSet`:

```dart
  const ChangeSet({
    this.currentXp,
    this.gold,
    this.traits = const [],
    this.electronicsClaim,
  });

  final num? currentXp;
  final num? gold;
  final List<TraitChange> traits;

  /// A request to spend one electronics day: the local 'YYYY-MM-DD' the
  /// player tapped Odbierz. Always the only entry in its ChangeSet.
  final String? electronicsClaim;

  bool get isEmpty =>
      currentXp == null &&
      gold == null &&
      traits.isEmpty &&
      electronicsClaim == null;
```
In `fromMap` add `electronicsClaim: _asString(data['electronics_claim']),`, and in `toMap` add `if (electronicsClaim != null) 'electronics_claim': electronicsClaim,`.

`lib/features/requests/change_request_formatting.dart`, in `changeSetLines` list, after the traits loop:

```dart
      if (changes.electronicsClaim != null)
        'Dzień z elektroniką: ${changes.electronicsClaim}',
```

- [ ] **Step 4: Run the tests**

Run: `flutter test` (whole suite) and `flutter analyze`
Expected: all PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/models/character.dart lib/models/change_request.dart lib/features/requests/change_request_formatting.dart test/models/character_test.dart test/models/change_request_test.dart test/features/change_request_formatting_test.dart
git commit -m "feat: carry electronics days on Character and claims on ChangeSet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Clock provider and transactional repository writes

**Files:**
- Create: `lib/providers/clock_provider.dart`
- Modify: `lib/data/character_repository.dart`
- Modify: `lib/data/change_request_repository.dart` (constructor clock, `_applyTo`)
- Modify: `lib/providers/character_providers.dart`, `lib/providers/change_request_providers.dart` (pass the clock)
- Test: `test/data/character_repository_test.dart`, `test/data/change_request_repository_test.dart`

**Interfaces:**
- Consumes: `ElectronicsDays`, `dayOf`, `parseDay` (Task 1); `ChangeSet.electronicsClaim` (Task 2)
- Produces:
  - `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);`
  - `CharacterRepository(FirebaseFirestore db, {DateTime Function()? clock})`
  - `Future<void> CharacterRepository.claimElectronicsDay(String characterId)`, which claims the clock's today
  - `Future<void> CharacterRepository.setElectronicsDays(String characterId, int value)`
  - `class CharacterNotFound implements Exception`, whose `toString()` is `'Postać już nie istnieje'`
  - `ChangeRequestRepository(FirebaseFirestore db, {DateTime Function()? clock})`
  - `accept` applies `electronicsClaim` to `characters/{id}.electronics` in the same transaction

- [ ] **Step 1: Write the failing tests**

Append to `test/data/character_repository_test.dart` (add imports `package:liferpg/models/electronics_days.dart` if missing):

```dart
  group('electronics', () {
    DateTime clock() => DateTime(2026, 10, 22, 15);

    test('claimElectronicsDay settles and claims today', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Ala',
        'email': 'a@example.com',
        'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
      });
      await CharacterRepository(db, clock: clock).claimElectronicsDay('c1');

      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data['electronics'], {
        'days': 4,
        'as_of': '2026-10-23',
        'claimed': ['2026-10-22'],
      });
    });

    test('claimElectronicsDay works on a character with no electronics map', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({'name': 'Ala', 'email': 'a@example.com'});
      await CharacterRepository(db, clock: () => DateTime(2026, 10, 13, 9))
          .claimElectronicsDay('c1');
      final e = ElectronicsDays.fromMap(
          (await db.collection('characters').doc('c1').get()).data()!['electronics']);
      expect(e.available(parseDay('2026-10-13')!), 2); // 3 accrued (10,11,12) - 1
      expect(e.isClaimed(parseDay('2026-10-13')!), isTrue);
    });

    test('setElectronicsDays writes today\'s value and keeps claimed', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Ala',
        'email': 'a@example.com',
        'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': ['2026-10-18']},
      });
      await CharacterRepository(db, clock: clock).setElectronicsDays('c1', 9);
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data['electronics'], {
        'days': 9,
        'as_of': '2026-10-22',
        'claimed': ['2026-10-18'],
      });
    });

    test('a missing character throws CharacterNotFound', () async {
      final db = FakeFirebaseFirestore();
      expect(
        () => CharacterRepository(db, clock: clock).claimElectronicsDay('nope'),
        throwsA(isA<CharacterNotFound>()),
      );
    });

    test('updateCharacter leaves electronics untouched', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Ala',
        'email': 'a@example.com',
        'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
      });
      final snap = await db.collection('characters').doc('c1').get();
      final stale = Character.fromMap('c1', snap.data()!);
      await CharacterRepository(db, clock: clock).claimElectronicsDay('c1');
      await CharacterRepository(db, clock: clock).updateCharacter(stale.copyWith(level: 9));
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect((data['electronics'] as Map)['days'], 4);
      expect(data['level'], 9);
    });
  });
```

Append to `test/data/change_request_repository_test.dart`:

```dart
  group('electronics claims', () {
    Future<(FakeFirebaseFirestore, ChangeRequestRepository, ChangeRequest)> setUpClaim({
      required String claimDay,
      required DateTime now,
      Map<String, dynamic>? electronics,
    }) async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Grommash',
        'email': 'ala@example.com',
        'electronics': ?electronics,
      });
      final repo = ChangeRequestRepository(db, clock: () => now);
      await repo.create(_request(changes: ChangeSet(electronicsClaim: claimDay)));
      final request = (await repo.watchPending().first).single;
      return (db, repo, request);
    }

    test('accepting a same-day claim spends a day and skips today', () async {
      final (db, repo, request) = await setUpClaim(
        claimDay: '2026-10-22',
        now: DateTime(2026, 10, 22, 20),
        electronics: {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
      );
      await repo.accept(request, adminUid: 'admin');
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data['electronics'], {
        'days': 4,
        'as_of': '2026-10-23',
        'claimed': ['2026-10-22'],
      });
      final req = (await db.collection('change_requests').doc(request.id).get()).data()!;
      expect(req['status'], 'accepted');
    });

    test('a claim accepted the next morning takes back the accrued day', () async {
      final (db, repo, request) = await setUpClaim(
        claimDay: '2026-10-22',
        now: DateTime(2026, 10, 23, 8),
        electronics: {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
      );
      await repo.accept(request, adminUid: 'admin');
      final e = ElectronicsDays.fromMap(
          (await db.collection('characters').doc('c1').get()).data()!['electronics']);
      // 3 + 20th + 21st = 5; 22nd claimed: -1 and not accrued -> 4.
      expect(e.available(parseDay('2026-10-23')!), 4);
    });

    test('accepting a claim for an already-claimed date changes nothing', () async {
      final (db, repo, request) = await setUpClaim(
        claimDay: '2026-10-22',
        now: DateTime(2026, 10, 22, 20),
        electronics: {'days': 4, 'as_of': '2026-10-23', 'claimed': ['2026-10-22']},
      );
      await repo.accept(request, adminUid: 'admin');
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data['electronics'], {
        'days': 4,
        'as_of': '2026-10-23',
        'claimed': ['2026-10-22'],
      });
    });

    test('an XP request does not touch electronics', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({'name': 'G', 'email': 'a@x', 'current_xp': 1});
      final repo = ChangeRequestRepository(db, clock: () => DateTime(2026, 10, 22));
      await repo.create(_request());
      await repo.accept((await repo.watchPending().first).single, adminUid: 'admin');
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data.containsKey('electronics'), isFalse);
    });
  });
```
(add `import 'package:liferpg/models/electronics_days.dart';`)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/character_repository_test.dart test/data/change_request_repository_test.dart`
Expected: compile errors (`clock:` param, `claimElectronicsDay`, `CharacterNotFound`).

- [ ] **Step 3: Implement**

`lib/providers/clock_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wall clock. Overridden in tests so day boundaries are deterministic;
/// new code reads this instead of calling DateTime.now() directly.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
```

`lib/data/character_repository.dart`:
- add `import '../models/electronics_days.dart';`
- add before the class:

```dart
/// Thrown when an electronics write re-reads the character mid-transaction
/// and it has vanished.
class CharacterNotFound implements Exception {
  const CharacterNotFound();

  @override
  String toString() => 'Postać już nie istnieje';
}
```
- constructor and methods:

```dart
  CharacterRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;
```

```dart
  /// An admin spending today's electronics day directly, no request needed.
  Future<void> claimElectronicsDay(String characterId) =>
      _updateElectronics(characterId, (e, today) => e.applyClaim(today, today));

  /// An admin's hand-set value (including a +1 bonus day).
  Future<void> setElectronicsDays(String characterId, int value) =>
      _updateElectronics(characterId, (e, today) => e.withValue(value, today));

  /// Read-modify-write in a transaction so a concurrent accept can't be lost.
  Future<void> _updateElectronics(
    String characterId,
    ElectronicsDays Function(ElectronicsDays current, int today) change,
  ) async {
    final ref = _db.collection('characters').doc(characterId);
    final today = dayOf(_clock());
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const CharacterNotFound();
      final next = change(ElectronicsDays.fromMap(data['electronics']), today);
      tx.update(ref, {'electronics': next.toMap()});
    });
  }
```

`lib/data/change_request_repository.dart`:
- add `import '../models/electronics_days.dart';`
- constructor: `ChangeRequestRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;` plus field `final DateTime Function() _clock;`
- at the end of `_applyTo`, before `return updates;`:

```dart
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
```

`lib/providers/character_providers.dart`: `CharacterRepository(ref.watch(firestoreProvider), clock: ref.watch(clockProvider))` (import `clock_provider.dart`).
`lib/providers/change_request_providers.dart`: `ChangeRequestRepository(ref.watch(firestoreProvider), clock: ref.watch(clockProvider))` (import `clock_provider.dart`).

- [ ] **Step 4: Run the tests**

Run: `flutter test` and `flutter analyze`
Expected: all PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/clock_provider.dart lib/data/character_repository.dart lib/data/change_request_repository.dart lib/providers/character_providers.dart lib/providers/change_request_providers.dart test/data/character_repository_test.dart test/data/change_request_repository_test.dart
git commit -m "feat: transactional electronics-day claims and admin value edits

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Firestore rules

**Files:**
- Modify: `firestore.rules` (the `change_requests` create rule and the `quests` create rule)
- Test: `tools/rules-test/rules.test.mjs`

**Interfaces:**
- Consumes: the wire shape `changes: { electronics_claim: 'YYYY-MM-DD' }` (Task 2)

- [ ] **Step 1: Write the failing tests**

Append to `tools/rules-test/rules.test.mjs`. They use the existing `ALICE`/`BOB` fixtures, `ctxFor`, and the `c-alice` character seeded by `seedCharacters()`:

```js
// --- electronics days ------------------------------------------------------

function claimRequest(user, characterId, changes) {
  return {
    characterId,
    characterName: 'Alicja',
    requesterUid: user.uid,
    requesterEmail: user.email,
    status: 'pending',
    changes,
    createdAt: serverTimestamp(),
  };
}

test('a user may request an electronics day for their own character', async () => {
  await assertSucceeds(setDoc(doc(ctxFor(ALICE), 'change_requests/el-ok'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: '2026-10-22' })));
});

test("a user may not request an electronics day for somebody else's character", async () => {
  await assertFails(setDoc(doc(ctxFor(BOB), 'change_requests/el-bob'),
    claimRequest(BOB, 'c-alice', { electronics_claim: '2026-10-22' })));
});

test('an electronics claim may not be combined with other changes', async () => {
  await assertFails(setDoc(doc(ctxFor(ALICE), 'change_requests/el-mixed'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: '2026-10-22', current_xp: 50 })));
});

test('an electronics claim must be a YYYY-MM-DD string', async () => {
  await assertFails(setDoc(doc(ctxFor(ALICE), 'change_requests/el-bad1'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: 'jutro' })));
  await assertFails(setDoc(doc(ctxFor(ALICE), 'change_requests/el-bad2'),
    claimRequest(ALICE, 'c-alice', { electronics_claim: 20261022 })));
});

test('a quest reward may not carry an electronics claim', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q-el'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30, electronics_claim: '2026-10-22' },
    })
  );
});
```

- [ ] **Step 2: Run them to verify the new ones fail**

Run, from the repository root (it needs a JDK; install deps once with `npm --prefix tools/rules-test ci --legacy-peer-deps` if `node_modules` is missing):

```bash
npx --yes firebase-tools emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"
```
Expected: "combined", "YYYY-MM-DD" and "quest reward" FAIL, because the writes are currently allowed. The others pass.

- [ ] **Step 3: Implement**

In `firestore.rules`, inside `match /change_requests/{requestId}`'s `allow create`, append this conjunct after the `characters/...` email check, before the `;`:

```
                    // An electronics-day claim is its own kind of request:
                    // the date the player tapped, nothing else alongside it.
                    && (!('electronics_claim' in request.resource.data.changes)
                        || (request.resource.data.changes.keys().hasOnly(['electronics_claim'])
                            && request.resource.data.changes.electronics_claim is string
                            && request.resource.data.changes.electronics_claim.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')))
```

In `match /quests/{questId}`'s `allow create`, after `&& !('gold' in request.resource.data.reward)`, add:

```
                    && !('electronics_claim' in request.resource.data.reward)
```

- [ ] **Step 4: Run the rules suite**

Run the same `emulators:exec` command.
Expected: every test PASSES, old and new.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/rules-test/rules.test.mjs
git commit -m "feat(rules): validate electronics-day claim requests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `ElectronicsSection` presentational widget, shared divider heading, and card slot

**Files:**
- Modify: `lib/theme/ornaments.dart` (add `LabelledDivider`)
- Modify: `lib/features/character/character_card.dart` (use `LabelledDivider` for Cechy; add the `electronics` slot)
- Create: `lib/features/character/electronics_section.dart`
- Test: create `test/features/electronics_section_test.dart`; extend `test/features/character_card_test.dart`

**Interfaces:**
- Consumes: `ElectronicsCardState` (Task 1)
- Produces:
  - `LabelledDivider({required String label})`, which renders `label.toUpperCase()` in `traitsDividerLabel` between two `crimsonBorderStrong` hairlines
  - `CharacterCard({required Character character, required bool canEdit, Widget? electronics})`, which renders `electronics` between the gold row and the favour/traits block
  - `ElectronicsSection({required int available, required ElectronicsCardState state, required double dayFraction, VoidCallback? onClaim, VoidCallback? onCancel})`
  - Keys: `electronics-count` (the count `Text`), `electronics-ring`, `electronics-claim`, `electronics-cancel`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/electronics_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/character/electronics_section.dart';
import 'package:liferpg/models/electronics_days.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('charging: count, Ładowanie…, status and ODBIERZ', (tester) async {
    var claimed = 0;
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 3,
      state: ElectronicsCardState.charging,
      dayFraction: 0.6,
      onClaim: () => claimed++,
    )));
    expect(find.text('DNI ELEKTRONIKI'), findsOneWidget);
    expect(find.byKey(const Key('electronics-count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('dostępne'), findsOneWidget);
    expect(find.text('DZISIEJSZY DZIEŃ'), findsOneWidget);
    expect(find.text('Ładowanie…'), findsOneWidget);
    expect(find.text('dzień bez elektroniki'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-claim')));
    expect(claimed, 1);
    expect(find.text('ODBIERZ'), findsOneWidget);
  });

  testWidgets('charging without onClaim shows no button', (tester) async {
    await tester.pumpWidget(wrap(const ElectronicsSection(
      available: 3, state: ElectronicsCardState.charging, dayFraction: 0.1)));
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('pending: question headline, status, ANULUJ PROŚBĘ', (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 3,
      state: ElectronicsCardState.pending,
      dayFraction: 0.6,
      onCancel: () => cancelled++,
    )));
    expect(find.text('Dzień z elektroniką?'), findsOneWidget);
    expect(find.text('czeka na akceptację'), findsOneWidget);
    expect(find.text('ANULUJ PROŚBĘ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-cancel')));
    expect(cancelled, 1);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('pending without onCancel (admin view) shows no button', (tester) async {
    await tester.pumpWidget(wrap(const ElectronicsSection(
      available: 3, state: ElectronicsCardState.pending, dayFraction: 0.6)));
    expect(find.text('czeka na akceptację'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('claimed: no button, odebrano dzisiaj', (tester) async {
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 2,
      state: ElectronicsCardState.claimed,
      dayFraction: 0.6,
      onClaim: () {},
      onCancel: () {},
    )));
    expect(find.text('Dzień z elektroniką'), findsOneWidget);
    expect(find.text('odebrano dzisiaj'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
    expect(find.byKey(const Key('electronics-cancel')), findsNothing);
  });

  testWidgets('empty: zero and no button even with onClaim', (tester) async {
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 0,
      state: ElectronicsCardState.empty,
      dayFraction: 0.6,
      onClaim: () {},
    )));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Ładowanie…'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });
}
```

Append to `test/features/character_card_test.dart` inside `main()`:

```dart
  testWidgets('renders the electronics slot between gold and traits', (tester) async {
    await tester.pumpWidget(wrap(CharacterCard(
      character: sample(traits: const [Trait(name: 'Siła', value: '18')]),
      canEdit: false,
      electronics: const Text('SLOT', key: Key('slot')),
    )));
    final gold = tester.getTopLeft(find.text('250 zł')).dy;
    final slot = tester.getTopLeft(find.byKey(const Key('slot'))).dy;
    final traits = tester.getTopLeft(find.text('CECHY')).dy;
    expect(gold < slot && slot < traits, isTrue);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/electronics_section_test.dart test/features/character_card_test.dart`
Expected: compile errors, because `ElectronicsSection` and `electronics:` are undefined.

- [ ] **Step 3: Implement**

`lib/theme/ornaments.dart`, which replaces the private `_TraitsHeading` in the card:

```dart
/// A centred label between two hairlines -- the Cechy / Dni elektroniki
/// section headings on the character card.
class LabelledDivider extends StatelessWidget {
  const LabelledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: crimsonBorderStrong, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label.toUpperCase(), style: traitsDividerLabel),
          ),
          const Expanded(child: Divider(color: crimsonBorderStrong, height: 1)),
        ],
      );
}
```

`lib/features/character/character_card.dart`:
- delete `_TraitsHeading` and replace its use with `const LabelledDivider(label: 'Cechy')`
- add `this.electronics` to the constructor, plus the field `/// The "Dni elektroniki" section, built by the home screen (it needs providers this widget deliberately doesn't). final Widget? electronics;`
- in the column, directly after `if (c.gold != null) _GoldRow(character: c),` insert:

```dart
                      if (widget.electronics != null) ...[
                        const SizedBox(height: 14),
                        widget.electronics!,
                      ],
```

`lib/features/character/electronics_section.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/electronics_days.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

const TextStyle _label = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  letterSpacing: 2,
  color: crimson,
);

const TextStyle _headline = TextStyle(
  fontFamily: fontBody,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  fontStyle: FontStyle.italic,
  color: inkHeading,
);

const TextStyle _status = TextStyle(
  fontFamily: fontBody,
  fontSize: 10,
  fontStyle: FontStyle.italic,
  color: crimson,
);

const TextStyle _buttonText = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 2,
);

/// The "Dni elektroniki" block on a character card: a ring medallion with
/// the available count, today's state, and at most one action. Purely
/// presentational -- ElectronicsPanel decides the state and the callbacks.
class ElectronicsSection extends StatelessWidget {
  const ElectronicsSection({
    super.key,
    required this.available,
    required this.state,
    required this.dayFraction,
    this.onClaim,
    this.onCancel,
  });

  final int available;
  final ElectronicsCardState state;

  /// Elapsed share of the local day, drawn as the ring's arc.
  final double dayFraction;

  /// Shown as ODBIERZ only in the charging state.
  final VoidCallback? onClaim;

  /// Shown as ANULUJ PROŚBĘ only in the pending state.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final (headline, status) = switch (state) {
      ElectronicsCardState.charging ||
      ElectronicsCardState.empty =>
        ('Ładowanie…', 'dzień bez elektroniki'),
      ElectronicsCardState.pending =>
        ('Dzień z elektroniką?', 'czeka na akceptację'),
      ElectronicsCardState.claimed =>
        ('Dzień z elektroniką', 'odebrano dzisiaj'),
    };

    final Widget? action = switch (state) {
      ElectronicsCardState.charging when onClaim != null => FilledButton.icon(
          key: const Key('electronics-claim'),
          onPressed: onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: crimson,
            foregroundColor: parchmentLight,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: const BorderSide(color: goldGlyph),
            ),
          ),
          icon: const Icon(Icons.smartphone, size: 16),
          label: Text('Odbierz'.toUpperCase(), style: _buttonText),
        ),
      ElectronicsCardState.pending when onCancel != null =>
        OutlinedButton.icon(
          key: const Key('electronics-cancel'),
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: crimson,
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: crimson),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          icon: const Icon(Icons.close, size: 16),
          label: Text('Anuluj prośbę'.toUpperCase(), style: _buttonText),
        ),
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LabelledDivider(label: 'Dni elektroniki'),
        const SizedBox(height: 12),
        Row(
          children: [
            _Medallion(
              available: available,
              state: state,
              dayFraction: dayFraction,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dzisiejszy dzień'.toUpperCase(), style: _label),
                  const SizedBox(height: 4),
                  Text(headline, style: _headline),
                  const SizedBox(height: 4),
                  Text(status, style: _status),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 14), action],
      ],
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({
    required this.available,
    required this.state,
    required this.dayFraction,
  });

  final int available;
  final ElectronicsCardState state;
  final double dayFraction;

  @override
  Widget build(BuildContext context) {
    final badge = switch (state) {
      ElectronicsCardState.pending =>
        (gold, inkHeading, Icons.hourglass_bottom),
      ElectronicsCardState.claimed => (crimson, parchmentLight, Icons.close),
      _ => null,
    };

    return SizedBox(
      key: const Key('electronics-ring'),
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(fraction: dayFraction, state: state),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: crimsonFaint,
                border: Border.all(color: crimson, width: 2),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$available',
                    key: const Key('electronics-count'),
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: inkHeading,
                    ),
                  ),
                  const Text(
                    'dostępne',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 8,
                      fontStyle: FontStyle.italic,
                      color: crimson,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.$1,
                  border: Border.all(color: parchmentLight, width: 2),
                ),
                child: Icon(badge.$3, size: 11, color: badge.$2),
              ),
            ),
        ],
      ),
    );
  }
}

/// The track plus today's arc: gold while charging, faded crimson while a
/// claim is pending, and a dashed crimson circle once today is claimed.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.state});

  final double fraction;
  final ElectronicsCardState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (state == ElectronicsCardState.claimed) {
      final dash = Paint()
        ..color = crimsonBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      const segments = 32;
      const sweep = 2 * math.pi / segments;
      for (var i = 0; i < segments; i++) {
        canvas.drawArc(rect, i * sweep, sweep * 0.45, false, dash);
      }
      return;
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = crimsonBorderFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = state == ElectronicsCardState.pending ? ornamentInk : gold
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.state != state;
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test` and `flutter analyze`
Expected: all PASS, no issues. The existing Cechy test still finds `CECHY`.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/ornaments.dart lib/features/character/character_card.dart lib/features/character/electronics_section.dart test/features/electronics_section_test.dart test/features/character_card_test.dart
git commit -m "feat: electronics days section widget and card slot

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `ElectronicsPanel`: state, roles, dialogs and actions, wired into the home screen

**Files:**
- Create: `lib/features/character/electronics_panel.dart`
- Modify: `lib/features/home/home_screen.dart` (pass `electronics: ElectronicsPanel(character: c)` to `CharacterCard`)
- Test: create `test/features/electronics_panel_test.dart`

**Interfaces:**
- Consumes:
  - `clockProvider`, `CharacterRepository.claimElectronicsDay` (Task 3)
  - `ChangeRequestRepository.create` / `.cancel`, `myChangeRequestsProvider`, `pendingChangeRequestsProvider`, `changeRequestRepositoryProvider` (existing)
  - `characterRepositoryProvider`, `appUserProvider` (existing)
  - `ElectronicsSection` (Task 5)
  - `dayOf`, `formatDay`, `dayFraction` (Task 1)
  - `showConfirmDialog` (`lib/theme/dialogs.dart`)
- Produces:
  - `ElectronicsPanel({required Character character})`
  - dialog keys `electronics-claim-confirm` (the confirm button of the claim dialog) and `electronics-cancel-confirm`

Behaviour (from the spec):
- `today = dayOf(clock())`.
- `todayKey = formatDay(today)`.
- A request "is today's claim" if all of these hold:
  - `isPending`;
  - `characterId == character.id`;
  - `changes.electronicsClaim == todayKey`.
- `ownPending` is the first such request in `myChangeRequestsProvider`.
- `hasPending` holds when `ownPending != null` or any such request is in `pendingChangeRequestsProvider` (which is empty for non-admins).
- `state = character.electronics.stateFor(today, hasPendingClaim: hasPending)`.
- `isOwner` compares `user.email` with `character.email`, both lower-cased.
- `onClaim`:
  - admin: direct-claim dialog, then `claimElectronicsDay`;
  - other owner: request dialog, then `create`;
  - anyone else: null.
- `onCancel`: only when `ownPending != null`. It shows the confirm dialog, then calls `cancel(ownPending)`.
- A `Timer.periodic(const Duration(minutes: 1))` calls `setState` and is cancelled in `dispose`.
- Errors show a `SnackBar` reading `'Nie udało się: $error'`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/electronics_panel_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/character/electronics_panel.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/clock_provider.dart';

const _owner = 'ala@example.com';

Future<FakeFirebaseFirestore> seed({
  required String uid,
  required String email,
  bool admin = false,
  bool readOnlyOthers = false,
  Map<String, dynamic>? electronics,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc(uid).set({
    'uid': uid,
    'name': 'X',
    'email': email,
    'admin': admin,
    'readOnlyOthers': readOnlyOthers,
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash',
    'email': _owner,
    'electronics':
        electronics ?? {'days': 3, 'as_of': '2026-10-22', 'claimed': []},
  });
  return db;
}

Future<Character> load(FakeFirebaseFirestore db) async =>
    Character.fromMap('c1', (await db.collection('characters').doc('c1').get()).data()!);

/// Re-pumps the panel with the character's current Firestore data, the way
/// the home screen's stream would.
Future<void> pumpPanel(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  required String uid,
  required String email,
  required DateTime Function() clock,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: email),
      )),
      clockProvider.overrideWithValue(clock),
    ],
    child: MaterialApp(
      home: Scaffold(body: ElectronicsPanel(character: await load(db))),
    ),
  ));
  await tester.pumpAndSettle();
}

DateTime noon() => DateTime(2026, 10, 22, 12);

void main() {
  testWidgets('owner sends a claim request after confirming', (tester) async {
    final db = await seed(uid: 'u1', email: _owner);
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: noon);

    expect(find.text('Ładowanie…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-claim')));
    await tester.pumpAndSettle();
    expect(find.text('DZIEŃ Z ELEKTRONIKĄ?'), findsOneWidget);
    expect(find.textContaining('Prośba trafi do admina'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-claim-confirm')));
    await tester.pumpAndSettle();

    final reqs = await db.collection('change_requests').get();
    expect(reqs.docs, hasLength(1));
    final r = reqs.docs.single.data();
    expect(r['changes'], {'electronics_claim': '2026-10-22'});
    expect(r['requesterUid'], 'u1');
    expect(r['status'], 'pending');
    expect(find.text('czeka na akceptację'), findsOneWidget);
    expect(find.byKey(const Key('electronics-cancel')), findsOneWidget);
  });

  testWidgets('owner can cancel a pending claim', (tester) async {
    final db = await seed(uid: 'u1', email: _owner);
    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': _owner,
      'status': 'pending',
      'changes': {'electronics_claim': '2026-10-22'},
    });
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: noon);

    await tester.tap(find.byKey(const Key('electronics-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('electronics-cancel-confirm')));
    await tester.pumpAndSettle();

    final r = (await db.collection('change_requests').get()).docs.single.data();
    expect(r['status'], 'cancelled');
    expect(find.text('Ładowanie…'), findsOneWidget);
  });

  testWidgets('a pending claim from yesterday does not block today', (tester) async {
    final db = await seed(uid: 'u1', email: _owner);
    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': _owner,
      'status': 'pending',
      'changes': {'electronics_claim': '2026-10-21'},
    });
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: noon);
    expect(find.byKey(const Key('electronics-claim')), findsOneWidget);
  });

  testWidgets('admin claims directly, no request', (tester) async {
    final db = await seed(uid: 'a1', email: 'admin@example.com', admin: true);
    await pumpPanel(tester, db, uid: 'a1', email: 'admin@example.com', clock: noon);

    await tester.tap(find.byKey(const Key('electronics-claim')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Odbierasz dzień dla postaci Grommash'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-claim-confirm')));
    await tester.pumpAndSettle();

    expect((await db.collection('change_requests').get()).docs, isEmpty);
    final e = (await db.collection('characters').doc('c1').get()).data()!['electronics'];
    expect((e as Map)['claimed'], ['2026-10-22']);
    expect(e['days'], 2);
  });

  testWidgets('admin sees a player\'s pending claim without a button', (tester) async {
    final db = await seed(uid: 'a1', email: 'admin@example.com', admin: true);
    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': _owner,
      'status': 'pending',
      'changes': {'electronics_claim': '2026-10-22'},
    });
    await pumpPanel(tester, db, uid: 'a1', email: 'admin@example.com', clock: noon);
    expect(find.text('czeka na akceptację'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
    expect(find.byKey(const Key('electronics-cancel')), findsNothing);
  });

  testWidgets('readOnlyOthers sees someone else\'s section without a button', (tester) async {
    final db = await seed(uid: 'r1', email: 'ro@example.com', readOnlyOthers: true);
    await pumpPanel(tester, db, uid: 'r1', email: 'ro@example.com', clock: noon);
    expect(find.text('Ładowanie…'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('at zero the button is hidden', (tester) async {
    final db = await seed(uid: 'u1', email: _owner,
        electronics: {'days': 0, 'as_of': '2026-10-22', 'claimed': []});
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: noon);
    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('the count rolls over at midnight while open', (tester) async {
    final db = await seed(uid: 'u1', email: _owner);
    var now = DateTime(2026, 10, 22, 23, 59, 30);
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: () => now);
    expect(find.text('3'), findsOneWidget);

    now = DateTime(2026, 10, 23, 0, 0, 30);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('4'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/electronics_panel_test.dart`
Expected: compile error, because `electronics_panel.dart` is missing.

- [ ] **Step 3: Implement**

```dart
// lib/features/character/electronics_panel.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../models/character.dart';
import '../../models/electronics_days.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/clock_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import 'electronics_section.dart';

/// Decides what the electronics section shows for the signed-in viewer and
/// wires its actions: a player's claim is a change request, an admin's is
/// applied at once. Rebuilds every minute so the ring advances and the count
/// rolls over at midnight while the app is open.
class ElectronicsPanel extends ConsumerStatefulWidget {
  const ElectronicsPanel({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<ElectronicsPanel> createState() => _ElectronicsPanelState();
}

class _ElectronicsPanelState extends ConsumerState<ElectronicsPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Nie udało się: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final now = ref.watch(clockProvider)();
    final today = dayOf(now);
    final todayKey = formatDay(today);
    final user = ref.watch(appUserProvider).value;

    bool isTodaysClaim(ChangeRequest r) =>
        r.isPending &&
        r.characterId == c.id &&
        r.changes.electronicsClaim == todayKey;

    final mine = ref.watch(myChangeRequestsProvider).value ?? const [];
    final queue = ref.watch(pendingChangeRequestsProvider).value ?? const [];
    final ownPending = mine.where(isTodaysClaim).firstOrNull;
    final hasPending = ownPending != null || queue.any(isTodaysClaim);

    final available = c.electronics.available(today);
    final state = c.electronics.stateFor(today, hasPendingClaim: hasPending);

    final isAdmin = user?.admin ?? false;
    final isOwner = user != null &&
        user.email.toLowerCase() == c.email.toLowerCase();

    VoidCallback? onClaim;
    if (user != null && isAdmin) {
      onClaim = () async {
        final ok = await _confirmClaim(
          available,
          'Odbierasz dzień dla postaci ${c.name}. Licznik spadnie od razu, '
              'a dzisiejszy dzień się nie doliczy.',
          'Odbierz',
        );
        if (!ok || !mounted) return;
        await _run(
          () => ref.read(characterRepositoryProvider).claimElectronicsDay(c.id),
          'Odebrano dzień elektroniki',
        );
      };
    } else if (user != null && isOwner) {
      onClaim = () async {
        final ok = await _confirmClaim(
          available,
          'Prośba trafi do admina. Po akceptacji licznik spadnie o jeden, '
              'a dzisiejszy dzień się nie doliczy.',
          'Wyślij prośbę',
        );
        if (!ok || !mounted) return;
        await _run(
          () => ref.read(changeRequestRepositoryProvider).create(ChangeRequest(
                id: '',
                characterId: c.id,
                characterName: c.name,
                requesterUid: user.uid,
                requesterEmail: user.email,
                status: ChangeRequestStatus.pending,
                changes: ChangeSet(electronicsClaim: todayKey),
              )),
          'Wysłano prośbę o odbiór dnia',
        );
      };
    }

    VoidCallback? onCancel;
    if (ownPending != null) {
      onCancel = () async {
        final ok = await showConfirmDialog(
          context,
          title: 'Anulować prośbę?',
          cancelLabel: 'Nie',
          confirmLabel: 'Tak, anuluj',
          confirmKey: const Key('electronics-cancel-confirm'),
        );
        if (!ok || !mounted) return;
        await _run(
          () => ref.read(changeRequestRepositoryProvider).cancel(ownPending),
          'Prośba anulowana',
        );
      };
    }

    return ElectronicsSection(
      available: available,
      state: state,
      dayFraction: dayFraction(now),
      onClaim: onClaim,
      onCancel: onCancel,
    );
  }

  /// The parchment confirm dialog, with the count's before -> after.
  Future<bool> _confirmClaim(int from, String body, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: crimson, width: 2),
        ),
        title: Text(
          'Dzień z elektroniką?'.toUpperCase(),
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: inkHeading,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$from', style: _countStyle(inkHeading)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.arrow_forward, color: crimson, size: 20),
                ),
                Text('${from - 1}', style: _countStyle(crimson)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 12,
                height: 1.6,
                color: inkDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: crimson),
            child: Text('Anuluj'.toUpperCase(), style: dialogActionStyle),
          ),
          TextButton(
            key: const Key('electronics-claim-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: crimson,
              foregroundColor: parchmentLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
                side: const BorderSide(color: goldGlyph),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(confirmLabel.toUpperCase(), style: dialogActionStyle),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static TextStyle _countStyle(Color color) => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );
}
```

`lib/features/home/home_screen.dart`: add `import '../character/electronics_panel.dart';`, and in the `CharacterCard(...)` call add `electronics: ElectronicsPanel(character: c),`.

- [ ] **Step 4: Run the tests**

Run: `flutter test` (whole suite, because `home_screen_test.dart` now renders the panel) and `flutter analyze`
Expected: all PASS, no issues. A home-screen test that fails only because it newly finds extra text such as `'3'` or `'0'` must be fixed by narrowing that test's finder, for example to `find.descendant` of the level badge. Never change the panel to suit it.

- [ ] **Step 5: Commit**

```bash
git add lib/features/character/electronics_panel.dart lib/features/home/home_screen.dart test/features/electronics_panel_test.dart
git commit -m "feat: electronics panel with request, direct claim and cancel flows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Add any home-screen test file you touched to the same commit.)

---

### Task 7: Admin edit screen value and inbox edit affordance

**Files:**
- Modify: `lib/features/character/edit_character_screen.dart`
- Modify: `lib/features/requests/change_requests_screen.dart` (hide `edit-<id>` for electronics claims)
- Test: `test/features/edit_character_screen_test.dart`, `test/features/change_requests_screen_test.dart`

**Interfaces:**
- Consumes: `clockProvider`, `CharacterRepository.setElectronicsDays` (Task 3); `Character.electronics.available` (Tasks 1 and 2); `ChangeSet.electronicsClaim` (Task 2)
- Produces:
  - keys `field-electronics` (TextFormField), `electronics-minus`, `electronics-plus` (IconButtons)

- [ ] **Step 1: Write the failing tests**

Append to `test/features/edit_character_screen_test.dart` inside `main()`. First extend `pumpEdit` with an optional `DateTime Function()? clock` parameter that adds `clockProvider.overrideWithValue(clock)` to the overrides when non-null, importing `package:liferpg/providers/clock_provider.dart`:

```dart
  testWidgets('shows today\'s electronics days and saves a +1 bonus', (tester) async {
    final (db, _) = await seed();
    final id = (await db.collection('characters').get()).docs.single.id;
    await db.collection('characters').doc(id).update({
      'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
    });
    final character = Character.fromMap(
        id, (await db.collection('characters').doc(id).get()).data()!);
    await pumpEdit(tester, db, character, clock: () => DateTime(2026, 10, 22, 9));

    expect(find.text('DNI ELEKTRONIKI'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-plus')));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, '6'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final e = (await db.collection('characters').doc(id).get()).data()!['electronics'];
    expect(e, {'days': 6, 'as_of': '2026-10-22', 'claimed': []});
  });

  testWidgets('an unchanged electronics value is not written', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character, clock: () => DateTime(2026, 10, 22, 9));
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();
    final data = (await db.collection('characters').doc(character.id).get()).data()!;
    expect(data.containsKey('electronics'), isFalse);
  });

  testWidgets('minus never goes below zero', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character, clock: () => DateTime(2026, 10, 10, 9));
    expect(find.widgetWithText(TextFormField, '0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-minus')));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, '0'), findsOneWidget);
  });
```

Append to `test/features/change_requests_screen_test.dart` inside `main()`. It uses that file's `seed()`, `pumpScreen()` and the top-level `requestId`:

```dart
  testWidgets('an electronics claim shows its date and offers no Edytuj', (tester) async {
    final db = await seed();
    await db.collection('change_requests').doc(requestId).update({
      'changes': {'electronics_claim': '2026-10-22'},
    });
    await pumpScreen(tester, db);

    expect(find.text('Dzień z elektroniką: 2026-10-22'), findsOneWidget);
    expect(find.byKey(Key('accept-$requestId')), findsOneWidget);
    expect(find.byKey(Key('edit-$requestId')), findsNothing);
  });

  testWidgets('an ordinary request still offers Edytuj', (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.byKey(Key('edit-$requestId')), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/edit_character_screen_test.dart test/features/change_requests_screen_test.dart`
Expected: FAIL, because there is no `DNI ELEKTRONIKI` row and `edit-<id>` is present.

- [ ] **Step 3: Implement**

`edit_character_screen.dart`:
- imports `../../models/electronics_days.dart` and `../../providers/clock_provider.dart`
- in state: `late final int _initialElectronics;` and add `'electronics'` to `_controllers`. In `initState`:

```dart
    _initialElectronics =
        c.electronics.available(dayOf(ref.read(clockProvider)()));
    _controllers['electronics'] =
        TextEditingController(text: '$_initialElectronics');
```
(build `_controllers` as a mutable map literal, or add the entry right after it is created)
- a stepper helper:

```dart
  void _stepElectronics(int delta) {
    final current = int.tryParse(_controllers['electronics']!.text.trim()) ?? 0;
    final next = (current + delta) < 0 ? 0 : current + delta;
    setState(() => _controllers['electronics']!.text = '$next');
  }
```
- in `_save()`, after `await ref.read(characterRepositoryProvider).updateCharacter(updated);`:

```dart
      final electronicsText = _controllers['electronics']!.text.trim();
      final electronics = int.tryParse(electronicsText);
      if (electronics != null && electronics != _initialElectronics) {
        await ref
            .read(characterRepositoryProvider)
            .setElectronicsDays(original.id, electronics < 0 ? 0 : electronics);
      }
```
- in the form column, directly after the XP `Row(...)` and before `if (kShowFavour) _favourRow(),`:

```dart
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Dni elektroniki'.toUpperCase(),
                                        style: _fieldLabel),
                                    Row(
                                      children: [
                                        IconButton(
                                          key: const Key('electronics-minus'),
                                          color: crimson,
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => _stepElectronics(-1),
                                        ),
                                        SizedBox(
                                          width: 48,
                                          child: _numberField('electronics',
                                              _controllers['electronics']!),
                                        ),
                                        IconButton(
                                          key: const Key('electronics-plus'),
                                          color: crimson,
                                          icon: const Icon(Icons.add),
                                          onPressed: () => _stepElectronics(1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
```

`change_requests_screen.dart`: wrap the `edit-${request.id}` `TextButton` in `if (request.changes.electronicsClaim == null)`, with the comment `// An electronics claim has nothing to edit: it is just a date.`

- [ ] **Step 4: Run the tests**

Run: `flutter test` and `flutter analyze`
Expected: all PASS, no issues. If an existing edit-screen test now matches two `'0'` TextFormFields, narrow it to `find.byKey(const Key('field-…'))`. Never change behaviour to suit it.

- [ ] **Step 5: Commit**

```bash
git add lib/features/character/edit_character_screen.dart lib/features/requests/change_requests_screen.dart test/features/edit_character_screen_test.dart test/features/change_requests_screen_test.dart
git commit -m "feat: admin sets electronics days by hand; claims are not editable in the inbox

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Documentation and full verification

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `CLAUDE.md`**

Under **Firestore Data Model** → `characters/{id}`, add `electronics: { days, as_of, claimed }  (optional)` to the field block. After the case-sensitivity bullet, add a bullet that:
- describes lazy accrual: available = `days` + full local days since `as_of`, with no cron;
- says every write settles first;
- names `kElectronicsDaysEpoch` (2026-10-10) as the default start;
- says `Character.toMap()` deliberately omits the map, and writes go only through `CharacterRepository.claimElectronicsDay` / `setElectronicsDays` and the accept transaction.

Under **`change_requests/{id}`**, add `electronics_claim?` to the `changes` shape. Add a bullet stating:
- it is the local `YYYY-MM-DD` the player tapped;
- it is always alone (enforced in rules);
- accepting applies `ElectronicsDays.applyClaim`, which is idempotent per date;
- a late approval takes back the already-accrued day.

Under **Key Behaviors**, add an **Electronics days** bullet summarising:
- the section is on every card;
- the four states and their copy;
- owner → request (cancellable), admin → immediate and also sees pending claims without a button;
- `readOnlyOthers` on others → no button;
- the button is hidden at 0;
- the admin's −/+ field in the edit screen;
- the one-minute ticker;
- `clockProvider` must be used instead of `DateTime.now()`.

- [ ] **Step 2: Full verification**

Run:
```bash
flutter analyze
flutter test
npx --yes firebase-tools emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"
```
Expected: no analyzer issues, all Flutter tests pass, and all rules tests pass.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document electronics days

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
