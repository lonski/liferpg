# Character Change Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any signed-in user post a structured request for changes to their own character (XP / gold / gold USD deltas plus trait upserts, with an optional reason), and give admins a screen to accept, edit-then-accept, or reject each request.

**Architecture:** A new top-level Firestore collection `change_requests`, read through a new `ChangeRequestRepository` exposed by Riverpod providers, following the existing `CharacterRepository` / `characterProviders` layering exactly. Accepting runs a single `runTransaction` on the admin's client that re-reads the character, applies the deltas, and flips the request's status atomically. Two new screens under `lib/features/requests/` share one form widget.

**Tech Stack:** Flutter / Dart, `cloud_firestore`, `flutter_riverpod` (Riverpod 3), `flutter_test` + `fake_cloud_firestore` + `firebase_auth_mocks`, plus the `@firebase/rules-unit-testing` emulator suite in `tools/rules-test/`.

**Spec:** `docs/superpowers/specs/2026-08-27-change-requests-design.md`

## Global Constraints

- **UI language is Polish.** Every user-visible string is Polish. Never translate an existing label. Labels that render uppercase do so via `.toUpperCase()` at the point of use; the Dart string literals stay in normal casing.
- **Firestore field names stay snake_case** (`current_xp`, `gold_usd`, `characterId` is camelCase because it is a *new* field with no React-era precedent — follow the spec's field list verbatim). Dart-side names are camelCase, mapped in the model.
- **Never touch `FirebaseFirestore.instance` or `FirebaseAuth.instance`** outside `lib/data/firebase_providers.dart`. Repositories take a `FirebaseFirestore` in their constructor; providers wire it from `firestoreProvider`.
- **Colours are `const Color(0xAARRGGBB)` literals** from `lib/theme/app_theme.dart`. Do not invent new colours; reuse `bgDark`, `crimson`, `gold`, `parchmentLight`, `parchmentMuted`, `goldBorder`, `appBarGradient`, `cardGradient`, `dialogShadowColor`.
- **Riverpod 3 caveats:** `AsyncValue.valueOrNull` does not exist — use `.value`. A `StreamProvider` stays paused until it has a listener, so in tests call `container.listen(someProvider, (_, _) {})` before `await container.read(someProvider.future)` or the test hangs forever.
- **Parsing is tolerant**, in the style of `Character.fromMap`: numbers may arrive as strings, unexpected types coerce to a sensible default rather than throwing.
- **TDD:** every task writes the failing test first, watches it fail, then implements. Run `flutter test` and `flutter analyze` before each commit.
- **`flutter analyze` must be clean** — no new warnings or infos.

---

### Task 1: The `ChangeRequest` model

**Files:**
- Create: `lib/models/change_request.dart`
- Test: `test/models/change_request_test.dart`

**Interfaces:**
- Consumes: `Trait` from `lib/models/character.dart` (not required, but the trait upsert list mirrors its `{name, value}` shape).
- Produces:
  - `class TraitChange { final String name; final String value; }` with `TraitChange.fromMap(Map<String, dynamic>)` and `Map<String, dynamic> toMap()`.
  - `class ChangeSet { final num? currentXp; final num? gold; final num? goldUsd; final List<TraitChange> traits; }` with `ChangeSet.fromMap`, `toMap()`, `bool get isEmpty`.
  - `enum ChangeRequestStatus { pending, accepted, rejected }` with `String get wire` and `static ChangeRequestStatus parse(Object?)`.
  - `class ChangeRequest` with fields `id, characterId, characterName, requesterUid, requesterEmail, status, reason, createdAt, changes, appliedChanges, decidedBy, decidedAt`, plus `ChangeRequest.fromMap(String id, Map<String, dynamic> data)` and `Map<String, dynamic> toMap()`.

- [ ] **Step 1: Write the failing tests**

Create `test/models/change_request_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';

void main() {
  test('parses a full document', () {
    final r = ChangeRequest.fromMap('r1', {
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'reason': 'Posprzątałem garaż',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      'changes': {
        'current_xp': 50,
        'gold': -10,
        'gold_usd': 2.5,
        'traits': [
          {'name': 'Siła', 'value': '12'},
        ],
      },
    });

    expect(r.id, 'r1');
    expect(r.characterId, 'c1');
    expect(r.characterName, 'Grommash');
    expect(r.requesterUid, 'u1');
    expect(r.status, ChangeRequestStatus.pending);
    expect(r.reason, 'Posprzątałem garaż');
    expect(r.changes.currentXp, 50);
    expect(r.changes.gold, -10);
    expect(r.changes.goldUsd, 2.5);
    expect(r.changes.traits.single.name, 'Siła');
    expect(r.changes.traits.single.value, '12');
    expect(r.appliedChanges, isNull);
    expect(r.decidedBy, isNull);
  });

  test('tolerates numbers written as strings and a missing changes map', () {
    final r = ChangeRequest.fromMap('r2', {
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': '50', 'gold': 'nonsense'},
    });

    expect(r.changes.currentXp, 50);
    expect(r.changes.gold, isNull);
    expect(r.changes.traits, isEmpty);
    expect(r.reason, isNull);
    expect(r.createdAt, isNull);
  });

  test('an unknown status parses as pending', () {
    final r = ChangeRequest.fromMap('r3', {
      'characterId': 'c1',
      'characterName': 'X',
      'requesterUid': 'u1',
      'requesterEmail': 'a@b.c',
      'status': 'weird',
      'changes': {'current_xp': 1},
    });
    expect(r.status, ChangeRequestStatus.pending);
  });

  test('toMap omits absent optional fields', () {
    final map = ChangeRequest(
      id: 'r1',
      characterId: 'c1',
      characterName: 'Grommash',
      requesterUid: 'u1',
      requesterEmail: 'ala@example.com',
      status: ChangeRequestStatus.pending,
      changes: const ChangeSet(currentXp: 50),
    ).toMap();

    expect(map['status'], 'pending');
    expect(map['changes'], {'current_xp': 50});
    expect(map.containsKey('reason'), isFalse);
    expect(map.containsKey('appliedChanges'), isFalse);
    expect(map.containsKey('decidedBy'), isFalse);
    expect(map.containsKey('decidedAt'), isFalse);
  });

  test('an empty ChangeSet is reported empty', () {
    expect(const ChangeSet().isEmpty, isTrue);
    expect(const ChangeSet(currentXp: 0).isEmpty, isFalse);
    expect(
      const ChangeSet(traits: [TraitChange(name: 'Siła', value: '1')]).isEmpty,
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/models/change_request_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:liferpg/models/change_request.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/models/change_request.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Documents in `change_requests` are written only by this app, but the
/// roster's history with a React-era database argues against trusting the
/// schema, so these coerce in the same style as `Character.fromMap`.
num? _asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

String? _asString(Object? v) => v is String ? v : null;

/// A single trait upsert: the trait with this `name` has its value replaced,
/// or is appended to the character if no trait carries that name. There is no
/// remove operation and no delta on a trait's value — the value is free-form
/// text, so a delta on it would be meaningless.
class TraitChange {
  const TraitChange({required this.name, required this.value});

  final String name;
  final String value;

  factory TraitChange.fromMap(Map<String, dynamic> data) => TraitChange(
        name: _asString(data['name']) ?? '',
        value: _asString(data['value']) ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is TraitChange && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// The numeric entries are **deltas**, not target values: a request stays
/// correct if the character changes between posting and acceptance.
class ChangeSet {
  const ChangeSet({
    this.currentXp,
    this.gold,
    this.goldUsd,
    this.traits = const [],
  });

  final num? currentXp;
  final num? gold;
  final num? goldUsd;
  final List<TraitChange> traits;

  bool get isEmpty =>
      currentXp == null && gold == null && goldUsd == null && traits.isEmpty;

  factory ChangeSet.fromMap(Map<String, dynamic> data) {
    final rawTraits = data['traits'];
    return ChangeSet(
      currentXp: _asNum(data['current_xp']),
      gold: _asNum(data['gold']),
      goldUsd: _asNum(data['gold_usd']),
      traits: rawTraits is List
          ? rawTraits
              .whereType<Map>()
              .map((t) => TraitChange.fromMap(Map<String, dynamic>.from(t)))
              .toList()
          : const <TraitChange>[],
    );
  }

  Map<String, dynamic> toMap() => {
        if (currentXp != null) 'current_xp': currentXp,
        if (gold != null) 'gold': gold,
        if (goldUsd != null) 'gold_usd': goldUsd,
        if (traits.isNotEmpty)
          'traits': traits.map((t) => t.toMap()).toList(),
      };
}

enum ChangeRequestStatus {
  pending,
  accepted,
  rejected;

  String get wire => name;

  /// Anything unrecognised is treated as pending: a request nobody can act on
  /// is worse than one that shows up in the queue again.
  static ChangeRequestStatus parse(Object? v) {
    for (final s in ChangeRequestStatus.values) {
      if (s.name == v) return s;
    }
    return ChangeRequestStatus.pending;
  }
}

class ChangeRequest {
  const ChangeRequest({
    required this.id,
    required this.characterId,
    required this.characterName,
    required this.requesterUid,
    required this.requesterEmail,
    required this.status,
    required this.changes,
    this.reason,
    this.createdAt,
    this.appliedChanges,
    this.decidedBy,
    this.decidedAt,
  });

  final String id;
  final String characterId;
  final String characterName;
  final String requesterUid;
  final String requesterEmail;
  final ChangeRequestStatus status;

  /// What was asked for. Preserved verbatim even when an admin edits the
  /// request before accepting — the edit lands in [appliedChanges].
  final ChangeSet changes;
  final String? reason;

  /// Null while the server timestamp is still pending on a local write.
  final DateTime? createdAt;

  /// What the admin actually applied. Null until accepted.
  final ChangeSet? appliedChanges;
  final String? decidedBy;
  final DateTime? decidedAt;

  bool get isPending => status == ChangeRequestStatus.pending;

  static DateTime? _asDate(Object? v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static ChangeSet? _asChangeSet(Object? v) =>
      v is Map ? ChangeSet.fromMap(Map<String, dynamic>.from(v)) : null;

  factory ChangeRequest.fromMap(String id, Map<String, dynamic> data) =>
      ChangeRequest(
        id: id,
        characterId: _asString(data['characterId']) ?? '',
        characterName: _asString(data['characterName']) ?? '',
        requesterUid: _asString(data['requesterUid']) ?? '',
        requesterEmail: _asString(data['requesterEmail']) ?? '',
        status: ChangeRequestStatus.parse(data['status']),
        changes: _asChangeSet(data['changes']) ?? const ChangeSet(),
        reason: _asString(data['reason']),
        createdAt: _asDate(data['createdAt']),
        appliedChanges: _asChangeSet(data['appliedChanges']),
        decidedBy: _asString(data['decidedBy']),
        decidedAt: _asDate(data['decidedAt']),
      );

  /// `createdAt` is deliberately absent: the repository writes it as a server
  /// timestamp rather than trusting the device clock.
  Map<String, dynamic> toMap() => {
        'characterId': characterId,
        'characterName': characterName,
        'requesterUid': requesterUid,
        'requesterEmail': requesterEmail,
        'status': status.wire,
        'changes': changes.toMap(),
        if (reason != null) 'reason': reason,
        if (appliedChanges != null) 'appliedChanges': appliedChanges!.toMap(),
        if (decidedBy != null) 'decidedBy': decidedBy,
        if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
      };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/models/change_request_test.dart && flutter analyze`
Expected: all tests PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/models/change_request.dart test/models/change_request_test.dart
git commit -m "feat: add ChangeRequest model for character change requests"
```

---

### Task 2: `ChangeRequestRepository` — create and watch

**Files:**
- Create: `lib/data/change_request_repository.dart`
- Test: `test/data/change_request_repository_test.dart`

**Interfaces:**
- Consumes: `ChangeRequest`, `ChangeSet`, `TraitChange`, `ChangeRequestStatus` from Task 1.
- Produces:
  - `class ChangeRequestRepository { ChangeRequestRepository(FirebaseFirestore db); }`
  - `Future<void> create(ChangeRequest request)` — writes `createdAt` as `FieldValue.serverTimestamp()`.
  - `Stream<List<ChangeRequest>> watchPending()`
  - `Stream<List<ChangeRequest>> watchForRequester(String uid)`

Both streams sort newest-first and skip malformed documents with a `debugPrint`, exactly as `CharacterRepository.watchCharacters` does.

- [ ] **Step 1: Write the failing tests**

Create `test/data/change_request_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_repository.dart';
import 'package:liferpg/models/change_request.dart';

ChangeRequest _request({
  String characterId = 'c1',
  String requesterUid = 'u1',
  ChangeSet changes = const ChangeSet(currentXp: 50),
  String? reason,
}) =>
    ChangeRequest(
      id: '',
      characterId: characterId,
      characterName: 'Grommash',
      requesterUid: requesterUid,
      requesterEmail: 'ala@example.com',
      status: ChangeRequestStatus.pending,
      changes: changes,
      reason: reason,
    );

void main() {
  test('create writes a pending request with a server timestamp', () async {
    final db = FakeFirebaseFirestore();
    await ChangeRequestRepository(db).create(_request(reason: 'Za sprzątanie'));

    final docs = await db.collection('change_requests').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.single.data();
    expect(data['status'], 'pending');
    expect(data['characterId'], 'c1');
    expect(data['requesterUid'], 'u1');
    expect(data['reason'], 'Za sprzątanie');
    expect(data['changes'], {'current_xp': 50});
    expect(data['createdAt'], isNotNull);
  });

  test('watchPending returns only pending requests', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    await repo.create(_request());
    await db.collection('change_requests').add({
      'characterId': 'c2',
      'characterName': 'Bob',
      'requesterUid': 'u2',
      'requesterEmail': 'bob@example.com',
      'status': 'accepted',
      'changes': {'gold': 5},
    });

    final pending = await repo.watchPending().first;

    expect(pending, hasLength(1));
    expect(pending.single.characterId, 'c1');
  });

  test('watchForRequester returns only that user\'s requests', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    await repo.create(_request(requesterUid: 'u1'));
    await repo.create(_request(requesterUid: 'u2'));

    final mine = await repo.watchForRequester('u1').first;

    expect(mine, hasLength(1));
    expect(mine.single.requesterUid, 'u1');
  });

  test('a malformed document is skipped rather than blanking the queue',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    await repo.create(_request());
    // A trait entry that is a Map with non-String keys survives the "is Map"
    // check yet throws inside Map<String, dynamic>.from.
    await db.collection('change_requests').add({
      'characterId': 'c9',
      'characterName': 'Corrupt',
      'requesterUid': 'u9',
      'requesterEmail': 'x@example.com',
      'status': 'pending',
      'changes': {
        'traits': [
          {1: 'a', 2: 'b'},
        ],
      },
    });

    final pending = await repo.watchPending().first;

    expect(pending, hasLength(1));
    expect(pending.single.characterId, 'c1');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:liferpg/data/change_request_repository.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/data/change_request_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/change_request.dart';

class ChangeRequestRepository {
  ChangeRequestRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('change_requests');

  /// `createdAt` is written server-side rather than from the device clock, so
  /// a device with a skewed clock cannot jump the queue.
  Future<void> create(ChangeRequest request) => _requests.add({
        ...request.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// The admin queue. The composite index on (status, createdAt) that this
  /// needs is declared in `firestore.indexes.json`.
  Stream<List<ChangeRequest>> watchPending() => _watch(
        _requests.where('status', isEqualTo: ChangeRequestStatus.pending.wire),
      );

  /// A requester's own history. The `requesterUid` constraint is not just a
  /// filter: the security rule only grants a non-admin read access to their
  /// own requests, so an unconstrained query would be rejected outright.
  Stream<List<ChangeRequest>> watchForRequester(String uid) =>
      _watch(_requests.where('requesterUid', isEqualTo: uid));

  Stream<List<ChangeRequest>> _watch(Query<Map<String, dynamic>> query) =>
      query.snapshots().map((snap) {
        final requests = snap.docs
            .map((d) {
              try {
                return ChangeRequest.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed change request ${d.id}: $e');
                return null;
              }
            })
            .whereType<ChangeRequest>()
            .toList();
        // Sorted client-side rather than with orderBy so that a request whose
        // server timestamp has not landed yet (createdAt still null on the
        // local write) is not dropped from the list.
        requests.sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return -1; // freshest: still being written
          if (bt == null) return 1;
          return bt.compareTo(at);
        });
        return requests;
      });
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/change_request_repository_test.dart && flutter analyze`
Expected: all tests PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/change_request_repository.dart test/data/change_request_repository_test.dart
git commit -m "feat: add ChangeRequestRepository create and watch queries"
```

---

### Task 3: Applying a request — `accept` and `reject`

**Files:**
- Modify: `lib/data/change_request_repository.dart`
- Test: `test/data/change_request_repository_test.dart` (append)

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces:
  - `Future<void> accept(ChangeRequest request, {ChangeSet? overrides, required String adminUid})`
  - `Future<void> reject(ChangeRequest request, {required String adminUid})`
  - `class ChangeRequestNoLongerPending implements Exception` — thrown when the transaction finds the request already decided.

- [ ] **Step 1: Write the failing tests**

Append to `test/data/change_request_repository_test.dart` (inside `main()`), and add `import 'package:liferpg/models/character.dart';` at the top of the file:

```dart
  Future<String> seedCharacter(
    FakeFirebaseFirestore db, {
    Map<String, dynamic> extra = const {},
  }) async {
    final ref = await db.collection('characters').add({
      'name': 'Grommash',
      'email': 'ala@example.com',
      'level': 3,
      'current_xp': 40,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
      ...extra,
    });
    return ref.id;
  }

  Future<ChangeRequest> onlyRequest(FakeFirebaseFirestore db) async {
    final docs = await db.collection('change_requests').get();
    final d = docs.docs.single;
    return ChangeRequest.fromMap(d.id, d.data());
  }

  test('accept adds the deltas to the character and marks the request',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db, extra: {'gold': 100});
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50, gold: -10),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 90);
    expect(character['gold'], 90);

    final decided = await onlyRequest(db);
    expect(decided.status, ChangeRequestStatus.accepted);
    expect(decided.decidedBy, 'admin1');
    expect(decided.decidedAt, isNotNull);
    expect(decided.appliedChanges!.currentXp, 50);
    expect(decided.appliedChanges!.gold, -10);
  });

  test('a delta against an absent field materialises it from zero', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    // No `gold` and no `gold_usd` key at all on this character.
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(gold: 10, goldUsd: 2.5),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['gold'], 10);
    expect(character['gold_usd'], 2.5);
  });

  test('trait upserts overwrite an existing name and append a new one',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db, extra: {
      'traits': [
        {'name': 'Siła', 'value': '10'},
      ],
    });
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(traits: [
        TraitChange(name: 'Siła', value: '12'),
        TraitChange(name: 'Spryt', value: '7'),
      ]),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character = Character.fromMap(
      characterId,
      (await db.collection('characters').doc(characterId).get()).data()!,
    );
    expect(character.traits.map((t) => '${t.name}=${t.value}').toList(),
        ['Siła=12', 'Spryt=7']);
  });

  test('overrides are applied and recorded while changes are preserved',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50),
    ));

    await repo.accept(
      await onlyRequest(db),
      overrides: const ChangeSet(currentXp: 20),
      adminUid: 'admin1',
    );

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 60);

    final decided = await onlyRequest(db);
    expect(decided.changes.currentXp, 50, reason: 'original ask is preserved');
    expect(decided.appliedChanges!.currentXp, 20);
  });

  test('accepting an already-decided request throws and does not re-apply',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50),
    ));
    final stale = await onlyRequest(db);
    await repo.accept(stale, adminUid: 'admin1');

    // `stale` still says pending — exactly the double-tap / stale-list case.
    await expectLater(
      repo.accept(stale, adminUid: 'admin1'),
      throwsA(isA<ChangeRequestNoLongerPending>()),
    );

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 90, reason: 'applied exactly once');
  });

  test('reject marks the request without touching the character', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50),
    ));

    await repo.reject(await onlyRequest(db), adminUid: 'admin1');

    final decided = await onlyRequest(db);
    expect(decided.status, ChangeRequestStatus.rejected);
    expect(decided.decidedBy, 'admin1');
    expect(decided.appliedChanges, isNull);

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 40, reason: 'untouched');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: FAIL — `The method 'accept' isn't defined for the type 'ChangeRequestRepository'`.

- [ ] **Step 3: Write the implementation**

Add to `lib/data/change_request_repository.dart` — first the exception, above the class:

```dart
/// Thrown when a transaction finds the request already accepted or rejected:
/// a double-tap, or a decision taken on another device while this list was
/// stale. Callers surface it as a message rather than re-applying the deltas.
class ChangeRequestNoLongerPending implements Exception {
  const ChangeRequestNoLongerPending();

  @override
  String toString() => 'Ta prośba została już rozpatrzona';
}
```

Then these members inside `ChangeRequestRepository`:

```dart
  /// Applies [overrides] if the admin edited the request before accepting,
  /// otherwise the request as posted. The character write and the status flip
  /// share one transaction, so either both land or neither does, and the
  /// re-read of the request makes a double-tap a no-op rather than a double
  /// application.
  Future<void> accept(
    ChangeRequest request, {
    ChangeSet? overrides,
    required String adminUid,
  }) async {
    final applied = overrides ?? request.changes;
    final requestRef = _requests.doc(request.id);
    final characterRef = _db.collection('characters').doc(request.characterId);

    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);
      final requestData = requestSnap.data();
      if (requestData == null ||
          ChangeRequestStatus.parse(requestData['status']) !=
              ChangeRequestStatus.pending) {
        throw const ChangeRequestNoLongerPending();
      }

      final characterSnap = await tx.get(characterRef);
      final character = characterSnap.data();
      if (character == null) {
        throw StateError('Character ${request.characterId} no longer exists');
      }

      tx.update(characterRef, _applyTo(character, applied));
      tx.update(requestRef, {
        'status': ChangeRequestStatus.accepted.wire,
        'appliedChanges': applied.toMap(),
        'decidedBy': adminUid,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reject(
    ChangeRequest request, {
    required String adminUid,
  }) async {
    final requestRef = _requests.doc(request.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      final data = snap.data();
      if (data == null ||
          ChangeRequestStatus.parse(data['status']) !=
              ChangeRequestStatus.pending) {
        throw const ChangeRequestNoLongerPending();
      }
      tx.update(requestRef, {
        'status': ChangeRequestStatus.rejected.wire,
        'decidedBy': adminUid,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// The character fields to write, given its current data. Only the fields
  /// the request actually touches appear, so accepting an XP-only request
  /// cannot invent a `gold: 0` row on a character that never had one.
  Map<String, dynamic> _applyTo(
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
      if (changes.goldUsd != null)
        'gold_usd': current('gold_usd') + changes.goldUsd!,
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
          traits[index] = change.toMap();
        } else {
          traits.add(change.toMap());
        }
      }
      updates['traits'] = traits;
    }

    return updates;
  }
```

Add `import '../models/change_request.dart';` if not already present (it is, from Task 2).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/change_request_repository_test.dart && flutter analyze`
Expected: all tests PASS, analyze clean.

If `FakeFirebaseFirestore` turns out not to support `runTransaction` with the reads used here, do **not** abandon the transaction — it is the correctness mechanism. Report the limitation, and cover `accept` in tests by driving the repository against the Firestore emulator instead, keeping the production code unchanged.

- [ ] **Step 5: Commit**

```bash
git add lib/data/change_request_repository.dart test/data/change_request_repository_test.dart
git commit -m "feat: apply change requests transactionally on accept"
```

---

### Task 4: Riverpod providers

**Files:**
- Create: `lib/providers/change_request_providers.dart`
- Test: `test/providers/change_request_providers_test.dart`

**Interfaces:**
- Consumes: `ChangeRequestRepository` (Tasks 2–3), `firestoreProvider` from `lib/data/firebase_providers.dart`, `appUserProvider` from `lib/providers/auth_providers.dart`.
- Produces:
  - `final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>(...)`
  - `final pendingChangeRequestsProvider = StreamProvider<List<ChangeRequest>>(...)` — empty for a non-admin.
  - `final myChangeRequestsProvider = StreamProvider<List<ChangeRequest>>(...)`

- [ ] **Step 1: Write the failing tests**

Create `test/providers/change_request_providers_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/providers/change_request_providers.dart';

Future<FakeFirebaseFirestore> seed({bool admin = false}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  await db.collection('change_requests').add({
    'characterId': 'c1',
    'characterName': 'Grommash',
    'requesterUid': 'u1',
    'requesterEmail': 'ala@example.com',
    'status': 'pending',
    'changes': {'current_xp': 50},
  });
  await db.collection('change_requests').add({
    'characterId': 'c2',
    'characterName': 'Bob',
    'requesterUid': 'u2',
    'requesterEmail': 'bob@example.com',
    'status': 'pending',
    'changes': {'gold': 5},
  });
  return db;
}

ProviderContainer containerFor(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
    )),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an admin sees every pending request', () async {
    final container = containerFor(await seed(admin: true));
    // Riverpod 3: a StreamProvider stays paused until it has a listener, so
    // awaiting `.future` without this hangs forever.
    container.listen(pendingChangeRequestsProvider, (_, _) {});

    final pending = await container.read(pendingChangeRequestsProvider.future);

    expect(pending, hasLength(2));
  });

  test('a non-admin sees no pending queue', () async {
    final container = containerFor(await seed());
    container.listen(pendingChangeRequestsProvider, (_, _) {});

    final pending = await container.read(pendingChangeRequestsProvider.future);

    expect(pending, isEmpty);
  });

  test('myChangeRequestsProvider returns only the signed-in user\'s requests',
      () async {
    final container = containerFor(await seed());
    container.listen(myChangeRequestsProvider, (_, _) {});

    final mine = await container.read(myChangeRequestsProvider.future);

    expect(mine, hasLength(1));
    expect(mine.single.requesterUid, 'u1');
    expect(mine.single.status, ChangeRequestStatus.pending);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/providers/change_request_providers_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:liferpg/providers/change_request_providers.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/providers/change_request_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/change_request_repository.dart';
import '../data/firebase_providers.dart';
import '../models/change_request.dart';
import 'auth_providers.dart';

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>(
  (ref) => ChangeRequestRepository(ref.watch(firestoreProvider)),
);

/// The admin queue. Empty for everyone else — the security rule would reject
/// the unconstrained query anyway, so issuing it would surface as a
/// PERMISSION_DENIED error rather than an empty list.
final pendingChangeRequestsProvider =
    StreamProvider<List<ChangeRequest>>((ref) async* {
  // Awaiting the resolved user rather than peeking at `.value`: reading
  // `.value` while appUserProvider is still loading is indistinguishable from
  // "signed out", which would race an empty queue out before the real user
  // ever resolves. Same reasoning as charactersProvider.
  final user = await ref.watch(appUserProvider.future);
  if (user == null || !user.admin) {
    yield const <ChangeRequest>[];
    return;
  }
  yield* ref.watch(changeRequestRepositoryProvider).watchPending();
});

/// The signed-in user's own requests, with their outcomes.
final myChangeRequestsProvider =
    StreamProvider<List<ChangeRequest>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <ChangeRequest>[];
    return;
  }
  yield* ref
      .watch(changeRequestRepositoryProvider)
      .watchForRequester(user.uid);
});
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/providers/change_request_providers_test.dart && flutter analyze`
Expected: all tests PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/change_request_providers.dart test/providers/change_request_providers_test.dart
git commit -m "feat: add change request providers"
```

---

### Task 5: The shared change-request form

**Files:**
- Create: `lib/features/requests/change_request_form.dart`
- Test: `test/features/change_request_form_test.dart`

**Interfaces:**
- Consumes: `ChangeSet`, `TraitChange` (Task 1); `traitNamesProvider` from `lib/providers/character_providers.dart`.
- Produces:
  - `class ChangeRequestForm extends ConsumerStatefulWidget` with
    `const ChangeRequestForm({super.key, this.initial, this.reason, this.showReason = true, required this.onChanged})`
    where `onChanged` is `void Function(ChangeSet changes, String? reason)`, called on every edit so the hosting screen can enable or disable its submit button.

The form is a pure input widget: it never writes to Firestore. Both the requester screen (Task 6) and the admin's edit-before-accept flow (Task 8) host it.

Widget keys the tests rely on: `field-current_xp`, `field-gold`, `field-gold_usd`, `field-reason`, `trait-name`, `trait-value`, `add-trait`, and `trait-row-<name>` per added trait.

- [ ] **Step 1: Write the failing tests**

Create `test/features/change_request_form_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/requests/change_request_form.dart';
import 'package:liferpg/models/change_request.dart';

Future<ChangeSet> Function() pumpForm(
  WidgetTester tester, {
  ChangeSet? initial,
}) {
  var latest = const ChangeSet();
  tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ChangeRequestForm(
          initial: initial,
          onChanged: (changes, _) => latest = changes,
        ),
      ),
    ),
  ));
  return () async => latest;
}

void main() {
  testWidgets('reports the typed deltas', (tester) async {
    final latest = pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.enterText(find.byKey(const Key('field-gold')), '-10');
    await tester.pump();

    final changes = await latest();
    expect(changes.currentXp, 50);
    expect(changes.gold, -10);
    expect(changes.goldUsd, isNull);
  });

  testWidgets('an empty field reports null rather than zero', (tester) async {
    final latest = pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('field-current_xp')), '');
    await tester.pump();

    expect((await latest()).currentXp, isNull);
    expect((await latest()).isEmpty, isTrue);
  });

  testWidgets('adds a trait upsert', (tester) async {
    final latest = pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('trait-name')), 'Siła');
    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trait-row-Siła')), findsOneWidget);
    expect((await latest()).traits.single,
        const TraitChange(name: 'Siła', value: '12'));
  });

  testWidgets('a trait with an empty name is not added', (tester) async {
    final latest = pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();

    expect((await latest()).traits, isEmpty);
  });

  testWidgets('prefills from an initial ChangeSet', (tester) async {
    pumpForm(
      tester,
      initial: const ChangeSet(
        currentXp: 50,
        traits: [TraitChange(name: 'Siła', value: '12')],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('field-current_xp')))
          .controller
          ?.text,
      '50',
    );
    expect(find.byKey(const Key('trait-row-Siła')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/change_request_form_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:liferpg/features/requests/change_request_form.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/requests/change_request_form.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';

const TextStyle _fieldLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 2,
  color: crimson,
);

/// Deltas may be negative, so unlike the character editor these accept a
/// leading minus. Empty means "no change to this field", never zero.
String? _validateOptionalDelta(String? value, {required bool decimal}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final parsed = decimal ? num.tryParse(text) : int.tryParse(text);
  return parsed == null ? 'Podaj liczbę' : null;
}

/// A pure input widget: it never writes to Firestore. The hosting screen owns
/// submission, so the requester screen and the admin's edit-before-accept
/// flow can share one implementation.
class ChangeRequestForm extends ConsumerStatefulWidget {
  const ChangeRequestForm({
    super.key,
    this.initial,
    this.reason,
    this.showReason = true,
    required this.onChanged,
  });

  final ChangeSet? initial;
  final String? reason;
  final bool showReason;
  final void Function(ChangeSet changes, String? reason) onChanged;

  @override
  ConsumerState<ChangeRequestForm> createState() => _ChangeRequestFormState();
}

class _ChangeRequestFormState extends ConsumerState<ChangeRequestForm> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _reasonController;
  final _newTraitValue = TextEditingController();
  // Owned by the Autocomplete below, not by us: we capture the instance it
  // hands to fieldViewBuilder so that _addTrait can actually clear the box,
  // and we must not dispose it. Same arrangement as EditCharacterScreen.
  TextEditingController? _traitNameController;
  late List<TraitChange> _traits;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controllers = {
      'current_xp': TextEditingController(
          text: initial?.currentXp?.toString() ?? ''),
      'gold': TextEditingController(text: initial?.gold?.toString() ?? ''),
      'gold_usd':
          TextEditingController(text: initial?.goldUsd?.toString() ?? ''),
    };
    _reasonController = TextEditingController(text: widget.reason ?? '');
    _traits = List<TraitChange>.from(initial?.traits ?? const <TraitChange>[]);
    for (final c in _controllers.values) {
      c.addListener(_emit);
    }
    _reasonController.addListener(_emit);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _reasonController.dispose();
    _newTraitValue.dispose();
    super.dispose();
  }

  num? _deltaOf(String key, {required bool decimal}) {
    final text = _controllers[key]!.text.trim();
    if (text.isEmpty) return null;
    return decimal ? num.tryParse(text) : int.tryParse(text);
  }

  ChangeSet get _changes => ChangeSet(
        currentXp: _deltaOf('current_xp', decimal: false),
        gold: _deltaOf('gold', decimal: true),
        goldUsd: _deltaOf('gold_usd', decimal: true),
        traits: _traits,
      );

  void _emit() {
    final reason = _reasonController.text.trim();
    widget.onChanged(_changes, reason.isEmpty ? null : reason);
  }

  void _addTrait() {
    final nameController = _traitNameController;
    final name = (nameController?.text ?? '').trim();
    // An empty value is a legitimate trait; an empty name is not.
    if (name.isEmpty) return;
    final value = _newTraitValue.text.trim();
    setState(() {
      // Re-adding a name already staged replaces it, matching the upsert
      // semantics the accept transaction uses.
      final index = _traits.indexWhere((t) => t.name == name);
      final entry = TraitChange(name: name, value: value);
      _traits = [..._traits];
      if (index >= 0) {
        _traits[index] = entry;
      } else {
        _traits.add(entry);
      }
    });
    nameController?.clear();
    _newTraitValue.clear();
    _emit();
  }

  void _removeTrait(String name) {
    setState(() {
      _traits = [
        for (final t in _traits)
          if (t.name != name) t,
      ];
    });
    _emit();
  }

  Widget _deltaField(String key, {required bool decimal}) => TextFormField(
        key: Key('field-$key'),
        controller: _controllers[key],
        keyboardType:
            TextInputType.numberWithOptions(decimal: decimal, signed: true),
        validator: (v) => _validateOptionalDelta(v, decimal: decimal),
        decoration: const InputDecoration(hintText: 'np. +50'),
      );

  @override
  Widget build(BuildContext context) {
    final traitNames = ref.watch(traitNamesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Labelled(
            label: 'XP', child: _deltaField('current_xp', decimal: false)),
        _Labelled(label: 'Złoto', child: _deltaField('gold', decimal: true)),
        _Labelled(
            label: 'Dolary', child: _deltaField('gold_usd', decimal: true)),
        const SizedBox(height: 12),
        Text('Cechy'.toUpperCase(), style: _fieldLabel),
        for (final trait in _traits)
          Row(
            key: Key('trait-row-${trait.name}'),
            children: [
              Expanded(
                child: Text(
                  '${trait.name}: ${trait.value}',
                  style: const TextStyle(color: traitNameInk),
                ),
              ),
              IconButton(
                tooltip: 'Usuń',
                icon: const Icon(Icons.close, size: 16, color: crimson),
                onPressed: () => _removeTrait(trait.name),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (value) {
                  final text = value.text.trim().toLowerCase();
                  if (text.isEmpty) return const Iterable<String>.empty();
                  return traitNames.where(
                      (n) => n.toLowerCase().contains(text));
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  _traitNameController = controller;
                  return TextFormField(
                    key: const Key('trait-name'),
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(hintText: 'Nazwa cechy'),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: const Key('trait-value'),
                controller: _newTraitValue,
                decoration: const InputDecoration(hintText: 'Wartość'),
              ),
            ),
            IconButton(
              key: const Key('add-trait'),
              tooltip: 'Dodaj cechę',
              icon: const Icon(Icons.add, color: crimson),
              onPressed: _addTrait,
            ),
          ],
        ),
        if (widget.showReason) ...[
          const SizedBox(height: 12),
          _Labelled(
            label: 'Powód',
            child: TextFormField(
              key: const Key('field-reason'),
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Opcjonalnie'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: _fieldLabel),
            SizedBox(width: 120, child: child),
          ],
        ),
      );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/change_request_form_test.dart && flutter analyze`
Expected: all tests PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/requests/change_request_form.dart test/features/change_request_form_test.dart
git commit -m "feat: add shared change request form widget"
```

---

### Task 6: `NewChangeRequestScreen`

**Files:**
- Create: `lib/features/requests/new_change_request_screen.dart`
- Test: `test/features/new_change_request_screen_test.dart`

**Interfaces:**
- Consumes: `ChangeRequestForm` (Task 5), `changeRequestRepositoryProvider` and `myChangeRequestsProvider` (Task 4), `charactersProvider` and `appUserProvider`.
- Produces: `class NewChangeRequestScreen extends ConsumerStatefulWidget { const NewChangeRequestScreen({super.key}); }`

Behaviour:
- The character list is the signed-in user's **own** characters: `feed.characters.where((c) => c.email.toLowerCase() == user.email.toLowerCase())`.
- A `DropdownButtonFormField` with key `character-picker` renders **only** when that list holds two or more characters. With exactly one, it is hidden and that character is used implicitly.
- The submit button (key `submit-request`) is disabled while the form reports an empty `ChangeSet`, and while a submit is in flight.
- On success, pop; on failure, a Polish `SnackBar`.
- Below the form, the user's own past requests from `myChangeRequestsProvider` with their status, each row keyed `my-request-<id>`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/new_change_request_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/requests/new_change_request_screen.dart';

Future<FakeFirebaseFirestore> seed({int characters = 1}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  for (var i = 0; i < characters; i++) {
    await db.collection('characters').add({
      'name': 'Bohater $i',
      'email': 'ala@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
  }
  return db;
}

Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: NewChangeRequestScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hides the character picker when there is only one character',
      (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.byKey(const Key('character-picker')), findsNothing);
  });

  testWidgets('shows the character picker when there are two characters',
      (tester) async {
    await pumpScreen(tester, await seed(characters: 2));
    expect(find.byKey(const Key('character-picker')), findsOneWidget);
  });

  testWidgets('submit is disabled until something is entered', (tester) async {
    await pumpScreen(tester, await seed());

    final button = () => tester
        .widget<ElevatedButton>(find.byKey(const Key('submit-request')));
    expect(button().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();

    expect(button().onPressed, isNotNull);
  });

  testWidgets('submitting writes a pending request', (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.enterText(
        find.byKey(const Key('field-reason')), 'Posprzątałem garaż');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-request')));
    await tester.pumpAndSettle();

    final docs = await db.collection('change_requests').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.single.data();
    expect(data['status'], 'pending');
    expect(data['requesterUid'], 'u1');
    expect(data['characterName'], 'Bohater 0');
    expect(data['reason'], 'Posprzątałem garaż');
    expect(data['changes'], {'current_xp': 50});
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/new_change_request_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:liferpg/features/requests/new_change_request_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/requests/new_change_request_screen.dart`. Structure it as a `Scaffold` with `backgroundColor: bgDark` and the same AppBar treatment as `EditCharacterScreen` (transparent background, `appBarGradient` flexibleSpace, `goldBorderFaint` bottom border, `iconTheme: IconThemeData(color: parchmentMuted)`), titled `'Prośba o zmianę'` in `fontDisplay` size 14 letterSpacing 3 `parchmentLight`. The body is a `SingleChildScrollView` with a `ConstrainedBox(maxWidth: 440)`, holding:

```dart
class NewChangeRequestScreen extends ConsumerStatefulWidget {
  const NewChangeRequestScreen({super.key});

  @override
  ConsumerState<NewChangeRequestScreen> createState() =>
      _NewChangeRequestScreenState();
}

class _NewChangeRequestScreenState
    extends ConsumerState<NewChangeRequestScreen> {
  ChangeSet _changes = const ChangeSet();
  String? _reason;
  String? _selectedCharacterId;
  bool _submitting = false;

  List<Character> _ownCharacters(WidgetRef ref, AppUser? user) {
    final feed = ref.watch(charactersProvider).value;
    if (feed == null || user == null) return const [];
    final email = user.email.toLowerCase();
    return [
      for (final c in feed.characters)
        if (c.email.toLowerCase() == email) c,
    ];
  }

  Future<void> _submit(Character character, AppUser user) async {
    setState(() => _submitting = true);
    try {
      await ref.read(changeRequestRepositoryProvider).create(ChangeRequest(
            id: '',
            characterId: character.id,
            characterName: character.name,
            requesterUid: user.uid,
            requesterEmail: user.email,
            status: ChangeRequestStatus.pending,
            changes: _changes,
            reason: _reason,
          ));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wysłać prośby: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final characters = _ownCharacters(ref, user);
    // With exactly one character the picker is pointless, so it is hidden and
    // that character is used implicitly.
    final selected = characters.isEmpty
        ? null
        : characters.firstWhere(
            (c) => c.id == _selectedCharacterId,
            orElse: () => characters.first,
          );
    final canSubmit =
        !_submitting && selected != null && user != null && !_changes.isEmpty;

    // ... Scaffold as described above, body children:
    //   if (characters.length > 1)
    //     DropdownButtonFormField<String>(
    //       key: const Key('character-picker'),
    //       initialValue: selected?.id,
    //       items: [for (final c in characters)
    //         DropdownMenuItem(value: c.id, child: Text(c.name))],
    //       onChanged: (id) => setState(() => _selectedCharacterId = id),
    //     ),
    //   ChangeRequestForm(
    //     onChanged: (changes, reason) =>
    //         setState(() { _changes = changes; _reason = reason; }),
    //   ),
    //   ElevatedButton(
    //     key: const Key('submit-request'),
    //     onPressed: canSubmit ? () => _submit(selected, user) : null,
    //     child: Text(_submitting ? '...' : 'Wyślij prośbę'.toUpperCase()),
    //   ),
    //   const OrnamentDivider(),
    //   ...the user's own past requests (see below)
  }
}
```

Fill in the commented body verbatim as described. Wrap the form in the same parchment card treatment `EditCharacterScreen` uses (a `Container` with `border: Border.all(color: crimson, width: 2)`, `borderRadius: BorderRadius.circular(4)`, `boxShadow` with `dialogShadowColor`, `clipBehavior: Clip.antiAlias`, an inner `Container` with `decoration: const BoxDecoration(gradient: cardGradient)` and padding, and a trailing `BottomBand()`), so the screen matches the rest of the app.

The history section renders `ref.watch(myChangeRequestsProvider).value ?? const []`:

```dart
for (final r in myRequests)
  Padding(
    key: Key('my-request-${r.id}'),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(r.characterName,
            style: const TextStyle(color: parchmentMuted)),
        Text(
          switch (r.status) {
            ChangeRequestStatus.pending => 'Oczekuje',
            ChangeRequestStatus.accepted => 'Zaakceptowana',
            ChangeRequestStatus.rejected => 'Odrzucona',
          },
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 9,
            letterSpacing: 2,
            color: parchmentFaint,
          ),
        ),
      ],
    ),
  ),
```

Imports needed: `package:flutter/material.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `../../models/app_user.dart`, `../../models/character.dart`, `../../models/change_request.dart`, `../../providers/auth_providers.dart`, `../../providers/change_request_providers.dart`, `../../providers/character_providers.dart`, `../../theme/app_theme.dart`, `../../theme/ornaments.dart`, `change_request_form.dart`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/new_change_request_screen_test.dart && flutter analyze`
Expected: all tests PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/requests/new_change_request_screen.dart test/features/new_change_request_screen_test.dart
git commit -m "feat: add screen for posting a character change request"
```

---

### Task 7: Home screen entry points — the FAB and the admin inbox action

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/home_screen_test.dart` (append)

**Interfaces:**
- Consumes: `NewChangeRequestScreen` (Task 6) and `ChangeRequestsScreen` (Task 8).
- **Ordering: execute Task 8 before this task.** This task's AppBar action imports `ChangeRequestsScreen`, which Task 8 creates; wiring it first would not compile. The plan lists them in this order only for narrative flow.
- Produces: a `floatingActionButton` on `HomeScreen` keyed `new-change-request`, and an AppBar action keyed `open-change-requests` shown only to admins.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/home_screen_test.dart` inside `main()`:

```dart
  testWidgets('offers the change-request FAB when the user has a character',
      (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('new-change-request')), findsOneWidget);
  });

  testWidgets('hides the change-request FAB when the user owns no character',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': false,
      'readOnlyOthers': false,
    });
    await pumpHome(tester, db);
    expect(find.byKey(const Key('new-change-request')), findsNothing);
  });

  testWidgets('shows the change-request queue action only for admins',
      (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('open-change-requests')), findsNothing);

    await pumpHome(tester, await seed(admin: true));
    expect(find.byKey(const Key('open-change-requests')), findsOneWidget);
  });

  testWidgets('the FAB opens the request screen', (tester) async {
    await pumpHome(tester, await seed());
    await tester.tap(find.byKey(const Key('new-change-request')));
    await tester.pumpAndSettle();
    expect(find.byType(NewChangeRequestScreen), findsOneWidget);
  });
```

Add these imports to the test file: `package:liferpg/features/requests/new_change_request_screen.dart`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/home_screen_test.dart`
Expected: FAIL — the new keys are not found.

- [ ] **Step 3: Write the implementation**

In `lib/features/home/home_screen.dart`:

Add imports for `../requests/change_requests_screen.dart`, `../requests/new_change_request_screen.dart`, and `../../models/character.dart` (the `Character` type is named in the `ownsACharacter` computation below and is not currently imported).

Inside `build`, after `final feed = ref.watch(charactersProvider);`:

```dart
    // An admin viewing the whole roster still only posts requests for their
    // own characters, so this counts by email rather than by roster size.
    final ownsACharacter = user != null &&
        (feed.value?.characters ?? const <Character>[]).any(
          (c) => c.email.toLowerCase() == user.email.toLowerCase(),
        );
```

Add to the AppBar `actions`, immediately before the existing `open-user-management` block:

```dart
          if (user?.admin ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: goldBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: IconButton(
                  key: const Key('open-change-requests'),
                  tooltip: 'Prośby o zmiany',
                  iconSize: 18,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  constraints: const BoxConstraints(),
                  color: parchmentMuted,
                  icon: const Icon(Icons.inbox),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangeRequestsScreen(),
                    ),
                  ),
                ),
              ),
            ),
```

Add to the `Scaffold`, alongside `body:`:

```dart
      floatingActionButton: ownsACharacter
          ? FloatingActionButton(
              key: const Key('new-change-request'),
              tooltip: 'Poproś o zmianę',
              backgroundColor: crimson,
              foregroundColor: parchmentLight,
              shape: const CircleBorder(
                side: BorderSide(color: goldBorder),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NewChangeRequestScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: the whole suite PASSES, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_screen.dart test/features/home_screen_test.dart
git commit -m "feat: add change-request FAB and admin queue action to home"
```

---

### Task 8: `ChangeRequestsScreen` — the admin queue

**Files:**
- Create: `lib/features/requests/change_requests_screen.dart`
- Test: `test/features/change_requests_screen_test.dart`

**Interfaces:**
- Consumes: `pendingChangeRequestsProvider`, `changeRequestRepositoryProvider` (Task 4); `ChangeRequestForm` (Task 5); `ChangeRequestNoLongerPending` (Task 3); `appUserProvider`.
- Produces: `class ChangeRequestsScreen extends ConsumerStatefulWidget { const ChangeRequestsScreen({super.key}); }`

Behaviour:
- Lists pending requests, newest first, each card keyed `request-<id>` and showing requester email, character name, the requested deltas rendered as signed text, and the reason if present.
- Per card: `accept-<id>`, `reject-<id>`, `edit-<id>` buttons, labelled `Zaakceptuj`, `Odrzuć`, `Edytuj`.
- `Edytuj` opens a dialog hosting `ChangeRequestForm` prefilled with `request.changes` and `showReason: false`, whose confirm button (key `confirm-edit`) accepts with those values as `overrides`.
- A filter chip row (keys `filter-pending`, `filter-accepted`, `filter-rejected`) defaults to pending. Accepted and rejected views read from `changeRequestRepositoryProvider` via a `StreamProvider.family` is **not** needed — instead filter client-side is also not possible since `watchPending` only queries pending. Add to the repository in this task:

```dart
  Stream<List<ChangeRequest>> watchByStatus(ChangeRequestStatus status) =>
      _watch(_requests.where('status', isEqualTo: status.wire));
```

and in `lib/providers/change_request_providers.dart`:

```dart
/// The admin queue filtered by status. `pendingChangeRequestsProvider` is the
/// pending case, kept separate because the home screen's badge watches it.
final changeRequestsByStatusProvider = StreamProvider.family<
    List<ChangeRequest>, ChangeRequestStatus>((ref, status) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null || !user.admin) {
    yield const <ChangeRequest>[];
    return;
  }
  yield* ref.watch(changeRequestRepositoryProvider).watchByStatus(status);
});
```

- A `ChangeRequestNoLongerPending` (or any other error) from accept/reject shows a Polish `SnackBar` with the message and leaves the list to refresh itself.

- [ ] **Step 1: Write the failing tests**

Create `test/features/change_requests_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/requests/change_requests_screen.dart';

late String characterId;
late String requestId;

Future<FakeFirebaseFirestore> seed({bool admin = true}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('a1').set({
    'uid': 'a1',
    'name': 'Admin',
    'email': 'admin@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  final character = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    'gold': 100,
    'favour': 0,
    'traits': <dynamic>[],
  });
  characterId = character.id;
  final request = await db.collection('change_requests').add({
    'characterId': characterId,
    'characterName': 'Grommash',
    'requesterUid': 'u1',
    'requesterEmail': 'ala@example.com',
    'status': 'pending',
    'reason': 'Posprzątałem garaż',
    'changes': {'current_xp': 50},
  });
  requestId = request.id;
  return db;
}

Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'a1', email: 'admin@example.com'),
      )),
    ],
    child: const MaterialApp(home: ChangeRequestsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists a pending request with its reason', (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
    expect(find.text('Grommash'), findsOneWidget);
    expect(find.text('Posprzątałem garaż'), findsOneWidget);
  });

  testWidgets('accepting applies the change and clears the queue',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('accept-$requestId')));
    await tester.pumpAndSettle();

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 90);
    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'accepted');
    expect(request['decidedBy'], 'a1');
    expect(find.byKey(Key('request-$requestId')), findsNothing);
  });

  testWidgets('rejecting marks the request without touching the character',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('reject-$requestId')));
    await tester.pumpAndSettle();

    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'rejected');
    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 40);
  });

  testWidgets('editing before accepting applies the edited value',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('edit-$requestId')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '20');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-edit')));
    await tester.pumpAndSettle();

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 60);
    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['changes'], {'current_xp': 50});
    expect(request['appliedChanges'], {'current_xp': 20});
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/change_requests_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:liferpg/features/requests/change_requests_screen.dart'`.

- [ ] **Step 3: Write the implementation**

First add `watchByStatus` to `ChangeRequestRepository` and `changeRequestsByStatusProvider` to the providers file, exactly as given in the Interfaces block above.

Then create `lib/features/requests/change_requests_screen.dart`, using the same AppBar treatment as the other screens with the title `'Prośby o zmiany'`, and:

```dart
class ChangeRequestsScreen extends ConsumerStatefulWidget {
  const ChangeRequestsScreen({super.key});

  @override
  ConsumerState<ChangeRequestsScreen> createState() =>
      _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends ConsumerState<ChangeRequestsScreen> {
  ChangeRequestStatus _filter = ChangeRequestStatus.pending;

  Future<void> _decide(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      // A ChangeRequestNoLongerPending lands here too: its toString is the
      // Polish "already decided" message, and the stream refreshes the list.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editThenAccept(ChangeRequest request, String adminUid) async {
    var edited = request.changes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: bgDark,
        title: const Text('Edytuj prośbę',
            style: TextStyle(color: parchmentLight)),
        content: SingleChildScrollView(
          child: ChangeRequestForm(
            initial: request.changes,
            showReason: false,
            onChanged: (changes, _) => edited = changes,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            key: const Key('confirm-edit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zaakceptuj'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _decide(
      () => ref.read(changeRequestRepositoryProvider).accept(
            request,
            overrides: edited,
            adminUid: adminUid,
          ),
      'Prośba zaakceptowana',
    );
  }

  // build(): a Scaffold whose body is
  //   - a Row of FilterChips keyed filter-pending / filter-accepted /
  //     filter-rejected, labelled 'Oczekujące' / 'Zaakceptowane' /
  //     'Odrzucone', each setting _filter
  //   - ref.watch(changeRequestsByStatusProvider(_filter)).when(
  //       loading: CircularProgressIndicator(color: gold),
  //       error: (e, _) => Text('Nie udało się wczytać próśb: $e'),
  //       data: (requests) => ListView of _RequestCard,
  //     )
}
```

`_RequestCard` is a `StatelessWidget` taking `request`, `adminUid`, `onAccept`, `onReject`, `onEdit`, keyed `Key('request-${request.id}')`, styled with the parchment card decoration used elsewhere (`cardGradient`, `crimsonBorder`, `CornerOrnament`s), rendering:

- the character name in `fontDisplay` 16 w700 `inkHeading`
- the requester email in `traitNameInk`
- one line per non-null delta, formatted with an explicit sign:
  ```dart
  String _signed(num v) => v > 0 ? '+$v' : '$v';
  ```
  labelled `XP`, `Złoto`, `Dolary`
- one line per trait upsert: `'${t.name}: ${t.value}'`
- the reason, if present
- and, only when `request.isPending`, a `Row` of three `TextButton`s keyed
  `accept-<id>` / `reject-<id>` / `edit-<id>` labelled `Zaakceptuj`, `Odrzuć`,
  `Edytuj`.

Wire them in `build` as:

```dart
onAccept: () => _decide(
  () => ref
      .read(changeRequestRepositoryProvider)
      .accept(request, adminUid: adminUid),
  'Prośba zaakceptowana',
),
onReject: () => _decide(
  () => ref
      .read(changeRequestRepositoryProvider)
      .reject(request, adminUid: adminUid),
  'Prośba odrzucona',
),
onEdit: () => _editThenAccept(request, adminUid),
```

where `adminUid` comes from `ref.watch(appUserProvider).value?.uid ?? ''`; render the loading indicator instead of the list while it is null.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: the whole suite PASSES, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/requests/change_requests_screen.dart lib/data/change_request_repository.dart lib/providers/change_request_providers.dart test/features/change_requests_screen_test.dart
git commit -m "feat: add admin change request queue screen"
```

---

### Task 9: Firestore security rules and the composite index

**Files:**
- Modify: `firestore.rules`
- Create or modify: `firestore.indexes.json`
- Test: `tools/rules-test/rules.test.mjs` (append)

**Interfaces:**
- Consumes: the document shape from Task 1 and the queries from Tasks 2 and 8.
- Produces: a `/change_requests/{requestId}` rule block.

Run these tests the way the existing rules suite is run — check `tools/rules-test/package.json` for the script and `.github/workflows/android-pr.yml` for how CI invokes it (it needs the Firestore emulator and JDK 21).

- [ ] **Step 1: Write the failing tests**

Append to `tools/rules-test/rules.test.mjs`. The existing `seedCharacters()` helper seeds characters with `withSecurityRulesDisabled`; add an analogous seed for requests. Alice is a regular user owning `characters/alice-char` with email `alice@example.com`; `admin` is an admin user.

```js
test('a user may create a request for their own character', async () => {
  const db = env.authenticatedContext('alice', {
    email: 'alice@example.com',
  }).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'change_requests/req-alice'), {
      characterId: 'alice-char',
      characterName: 'Alice',
      requesterUid: 'alice',
      requesterEmail: 'alice@example.com',
      status: 'pending',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may not create a request for somebody else\'s character', async () => {
  const db = env.authenticatedContext('mallory', {
    email: 'mallory@example.com',
  }).firestore();
  await assertFails(
    setDoc(doc(db, 'change_requests/req-mallory'), {
      characterId: 'alice-char',
      characterName: 'Alice',
      requesterUid: 'mallory',
      requesterEmail: 'mallory@example.com',
      status: 'pending',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may not create a request in somebody else\'s name', async () => {
  const db = env.authenticatedContext('alice', {
    email: 'alice@example.com',
  }).firestore();
  await assertFails(
    setDoc(doc(db, 'change_requests/req-spoofed'), {
      characterId: 'alice-char',
      characterName: 'Alice',
      requesterUid: 'someone-else',
      requesterEmail: 'alice@example.com',
      status: 'pending',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may not create a request that is already accepted', async () => {
  const db = env.authenticatedContext('alice', {
    email: 'alice@example.com',
  }).firestore();
  await assertFails(
    setDoc(doc(db, 'change_requests/req-preaccepted'), {
      characterId: 'alice-char',
      characterName: 'Alice',
      requesterUid: 'alice',
      requesterEmail: 'alice@example.com',
      status: 'accepted',
      changes: { current_xp: 50 },
      createdAt: serverTimestamp(),
    })
  );
});

test('a user may read their own requests but not somebody else\'s', async () => {
  await seedRequest('req-alice-seeded', 'alice');
  await seedRequest('req-bob-seeded', 'bob');
  const db = env.authenticatedContext('alice', {
    email: 'alice@example.com',
  }).firestore();

  await assertSucceeds(getDoc(doc(db, 'change_requests/req-alice-seeded')));
  await assertFails(getDoc(doc(db, 'change_requests/req-bob-seeded')));
  await assertSucceeds(
    getDocs(
      query(
        collection(db, 'change_requests'),
        where('requesterUid', '==', 'alice')
      )
    )
  );
  await assertFails(getDocs(collection(db, 'change_requests')));
});

test('an admin may read every request and decide it', async () => {
  await seedRequest('req-for-admin', 'alice');
  const db = env.authenticatedContext('admin', {
    email: 'admin@example.com',
  }).firestore();

  await assertSucceeds(getDocs(collection(db, 'change_requests')));
  await assertSucceeds(
    updateDoc(doc(db, 'change_requests/req-for-admin'), {
      status: 'accepted',
      decidedBy: 'admin',
      decidedAt: serverTimestamp(),
      appliedChanges: { current_xp: 50 },
    })
  );
});

test('a non-admin may not decide a request, even their own', async () => {
  await seedRequest('req-self-decide', 'alice');
  const db = env.authenticatedContext('alice', {
    email: 'alice@example.com',
  }).firestore();
  await assertFails(
    updateDoc(doc(db, 'change_requests/req-self-decide'), {
      status: 'accepted',
      decidedBy: 'alice',
    })
  );
});
```

Add the `seedRequest` helper alongside the existing seeding code:

```js
async function seedRequest(id, requesterUid) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `change_requests/${id}`), {
      characterId: 'alice-char',
      characterName: 'Alice',
      requesterUid,
      requesterEmail: `${requesterUid}@example.com`,
      status: 'pending',
      changes: { current_xp: 50 },
    });
  });
}
```

Extend the existing `seedCharacters()` so that `characters/alice-char` exists with `email: 'alice@example.com'`, and ensure `users/admin` exists with `admin: true` (the existing suite already seeds an admin — reuse whatever uid it uses and adjust the tests above to match rather than duplicating it). Add `updateDoc` and `serverTimestamp` to the `firebase/firestore` import list if they are not already imported.

- [ ] **Step 2: Run the tests to verify they fail**

Run the rules suite (check `tools/rules-test/package.json` for the exact script — likely `npm test` from `tools/rules-test/`, with `JAVA_HOME` set to JDK 21 if the emulator complains).
Expected: the new tests FAIL — with no rule for `/change_requests`, every operation is denied, so the `assertSucceeds` cases fail.

- [ ] **Step 3: Write the implementation**

Add to `firestore.rules`, inside the `documents` match block, after the `characters` block:

```
    match /change_requests/{requestId} {
      // A non-admin's read is only granted for their own requests, so the
      // client must keep issuing where('requesterUid', isEqualTo: <own uid>)
      // -- an unconstrained collection query is rejected outright, exactly as
      // it is for /characters.
      allow read: if isAdmin()
                     || (isAuthenticated()
                         && resource.data.requesterUid == request.auth.uid);

      // A request must be posted in your own name, against your own
      // character, and as pending: the decision fields are the admin's to
      // write, never the requester's.
      allow create: if isAuthenticated()
                    && request.resource.data.requesterUid == request.auth.uid
                    && request.resource.data.status == 'pending'
                    && !('decidedBy' in request.resource.data)
                    && !('decidedAt' in request.resource.data)
                    && !('appliedChanges' in request.resource.data)
                    && get(/databases/$(database)/documents/characters/$(request.resource.data.characterId))
                         .data.email.lower() == request.auth.token.email.lower();

      // Accepting also writes /characters/{id}, which is already admin-only,
      // so the whole apply path runs as an admin.
      allow update, delete: if isAdmin();
    }
```

Then declare the composite index the admin queue needs. If `firestore.indexes.json` does not exist, create it:

```json
{
  "indexes": [
    {
      "collectionGroup": "change_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "change_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "requesterUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

If it already exists, merge these two entries into its `indexes` array rather than replacing the file.

Note: the repository sorts client-side rather than with `orderBy`, so these indexes are not strictly required today — they are declared so that adding `orderBy` later, or the console suggesting them, does not surprise anyone. Do **not** change the repository to use `orderBy`: the client-side sort exists so a request whose server timestamp has not landed yet is not dropped.

- [ ] **Step 4: Run the tests to verify they pass**

Run the rules suite again.
Expected: all tests PASS, including the pre-existing ones.

Then run `flutter test && flutter analyze` one final time to confirm nothing else regressed.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firestore.indexes.json tools/rules-test/rules.test.mjs
git commit -m "feat: secure change_requests with owner-scoped rules"
```

---

### Task 10: Documentation

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: everything above. Produces no code.

- [ ] **Step 1: Update the data model section**

Add to the **Firestore Data Model** section of `CLAUDE.md`, after the `characters/{id}` block:

```markdown
**`change_requests/{id}`**
```
characterId, characterName, requesterUid, requesterEmail
status: 'pending' | 'accepted' | 'rejected'
reason (optional), createdAt (server timestamp)
changes:        { current_xp?, gold?, gold_usd?, traits?: [{name, value}] }
appliedChanges: same shape, written on accept
decidedBy, decidedAt: written on accept/reject
```

- Numeric entries in `changes` are **deltas**, not target values, so a request
  stays correct if the character changes before an admin accepts it. Trait
  entries are **upserts by name**: a matching trait's value is replaced, a new
  name is appended. There is no remove operation.
- Any signed-in user may post a request **for their own character only**;
  the rule checks the target character's email against the caller's, and that
  the request names the caller as `requesterUid` and is `pending`.
- Only admins may read the whole collection or update a request. A regular
  user's query must therefore carry
  `where('requesterUid', isEqualTo: <own uid>)`, exactly like the roster's
  own-email query.
- Accepting runs a `runTransaction` on the **admin's client** (there are no
  Cloud Functions in this project): it re-reads the request, aborts with
  `ChangeRequestNoLongerPending` if it is no longer pending, applies the
  deltas to the character, and flips the status — all atomically, so a
  double-tap cannot apply a request twice.
- `ChangeRequestRepository` sorts newest-first **client-side** rather than with
  `orderBy`. This is deliberate: a request whose server timestamp has not
  landed yet has a null `createdAt` and an `orderBy` query would drop it.
```

- [ ] **Step 2: Note the feature in Key Behaviors**

Add a bullet to the **Key Behaviors** section:

```markdown
- **Change requests**: a round `+` FAB on the home screen (shown to any user
  who owns a character) opens a form for requesting XP / gold / trait changes.
  Admins get an inbox action in the AppBar opening the queue, where each
  request can be accepted, edited-then-accepted, or rejected.
```

- [ ] **Step 3: Verify the whole suite one last time**

Run: `flutter test && flutter analyze`
Expected: all PASS, analyze clean.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document the change requests collection and flow"
```
