# Quest Management (Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working quest system — post to an open board or assign directly to a character, take/abandon/withdraw, mark complete (which raises a normal `ChangeRequest` for admin review), a global outcome log, an admin-curated roster of assignable characters, notifications, and a redesigned FAB.

**Architecture:** Follows the existing repository → provider → feature layering used by `change_requests`. A quest's completion *is* an ordinary `ChangeRequest` document (cross-linked via a new `questId`/`questTitle` pair) so the existing admin accept/reject screen, transaction, and notification path are extended rather than duplicated. A new `quest_roster` collection — name/id/email only, admin-write, everyone-read — is the sole new public read surface; the `characters` collection's rules are untouched.

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod` 3.x — remember `.value` not `.valueOrNull`, and stream providers need a listener attached before `await ... .future` in tests), Firestore + `firestore.rules`, `fake_cloud_firestore`/`firebase_auth_mocks` for repo/widget tests, `@firebase/rules-unit-testing` (`tools/rules-test/rules.test.mjs`) for rules tests.

**Spec:** `docs/superpowers/specs/2026-08-28-quest-management-design.md` — this plan implements its core-quest scope. Daily quest templates (spec sections "Daily Quests" and the `daily_quest_templates` collection) are **out of scope for this plan** and will be a follow-up plan that builds on it.

## Global Constraints

- UI is Polish throughout; labels render uppercase via `.toUpperCase()` at the call site, never in the string literal itself.
- Quest rewards are XP and/or trait changes only — never gold. Reuse `ChangeSet`/`TraitChange` from `lib/models/change_request.dart` directly as the reward type (do not invent a parallel `QuestReward` model); a quest's reward simply never populates `gold`.
- New collections created by this feature (`quests`, `quest_roster`) use camelCase wire field names, matching `change_requests` — **not** the legacy snake_case of `characters` (that snake_case exists only because the React app wrote it). The one exception is inside the embedded `reward` map, which is `ChangeSet.toMap()`'s own shape (`current_xp`, `traits`) — leave that as-is, it's already established.
- Nothing outside `lib/data/firebase_providers.dart` touches `FirebaseAuth.instance`/`FirebaseFirestore.instance` directly; `SharedPreferences.getInstance()` is reached only through `lib/data/shared_preferences_provider.dart`.
- No Cloud Functions exist in this project and none are added here.
- Every repository transaction that guards a state transition re-reads its target inside the transaction and throws a typed exception (with a Polish `toString()`) on a stale/already-transitioned status — never a silent no-op, never a double application. This mirrors `ChangeRequestRepository._readPending`.
- Malformed documents are skipped with `debugPrint`, never thrown from a stream mapper — mirrors `ChangeRequestRepository._watch`/`CharacterRepository.watchCharacters`.
- No composite Firestore indexes are needed for this plan: every quest query is a single-field `where`/`whereIn` with client-side sorting (same shape `change_requests` already uses without truly needing its declared index). Do not add entries to `firestore.indexes.json` unless a task below explicitly says to.
- `flutter analyze` and `flutter test` must both stay clean after every task.

---

## File Structure

New files:
- `lib/models/quest.dart` — `Quest`, `QuestStatus`.
- `lib/models/quest_roster_entry.dart` — `QuestRosterEntry`.
- `lib/data/quest_repository.dart` — `QuestRepository` and its exceptions.
- `lib/data/quest_roster_repository.dart` — `QuestRosterRepository`.
- `lib/data/quest_notification_repository.dart` — SharedPreferences baselines for the three quest notification events.
- `lib/data/quest_notifications.dart` — the generic `diffNewIds` helper.
- `lib/providers/quest_providers.dart` — repo providers + `openQuestsProvider`/`myAssignedQuestsProvider`/`myPostedQuestsProvider`/`questLogProvider`/`questRosterProvider`/`myOwnCharacterIdsProvider`.
- `lib/providers/quest_notification_providers.dart` — `questNotificationsProvider`, reusing the existing `changeRequestNotificationServiceProvider`.
- `lib/features/quests/quest_card.dart` — the shared ornamental quest card.
- `lib/features/quests/quests_screen.dart` — the tabbed host (Tablica / Moje / Dziennik).
- `lib/features/quests/new_quest_screen.dart` — the posting form.

Modified files:
- `lib/models/change_request.dart` — add `questId`/`questTitle`.
- `lib/data/change_request_repository.dart` — `accept`/`reject` also flip a linked quest.
- `lib/features/home/home_screen.dart` — FAB becomes a speed-dial.
- `lib/features/requests/change_requests_screen.dart` — `_RequestCard` gains a quest-reference line.
- `lib/features/requests/new_change_request_screen.dart` — the own-history detail dialog gains the same line.
- `lib/features/users/user_management_screen.dart` — a new "Uczestnicy zadań" section.
- `firestore.rules` — new `quests`/`quest_roster` blocks.
- `lib/main.dart` — `AuthGate` also watches `questNotificationsProvider`.

---

### Task 1: `Quest`/`QuestStatus` model

**Files:**
- Create: `lib/models/quest.dart`
- Test: `test/models/quest_test.dart`

**Interfaces:**
- Produces: `enum QuestStatus { open, assigned, pendingReview, completed, failed, cancelled }` with `String get wire` (snake_case only for `pendingReview` → `'pending_review'`, else `name`) and `static QuestStatus parse(Object? v)` (unrecognised → `open`, mirroring `ChangeRequestStatus.parse`'s "unrecognised is treated as the safest default" reasoning — here "still needs action" is `open`, not a decided state).
- Produces: `class Quest` — `id, title, description (String?), posterUid, posterEmail, posterName, assignedToCharacterId (String?), assignedToCharacterName (String?), assignedToEmail (String?), status (QuestStatus), reward (ChangeSet), changeRequestId (String?), createdAt (DateTime?)`, `factory Quest.fromMap(String id, Map<String, dynamic> data)`, `Map<String, dynamic> toMap()` (omits `createdAt` — written server-side by the repository, mirrors `ChangeRequest.toMap()`).

- [ ] **Step 1: Write the failing test**

```dart
// test/models/quest_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

void main() {
  group('QuestStatus', () {
    test('wire round-trips pending_review', () {
      expect(QuestStatus.pendingReview.wire, 'pending_review');
      expect(QuestStatus.parse('pending_review'), QuestStatus.pendingReview);
    });

    test('parse defaults unrecognised values to open', () {
      expect(QuestStatus.parse('nonsense'), QuestStatus.open);
      expect(QuestStatus.parse(null), QuestStatus.open);
    });
  });

  group('Quest', () {
    test('toMap/fromMap round trip for an open board quest', () {
      const quest = Quest(
        id: 'q1',
        title: 'Posprzątaj garaż',
        description: 'Naprawdę duży bałagan',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Ala',
        status: QuestStatus.open,
        reward: ChangeSet(currentXp: 50, traits: [TraitChange(name: 'Porządek', value: '+1')]),
      );

      final map = quest.toMap();
      expect(map['status'], 'open');
      expect(map.containsKey('assignedToCharacterId'), isFalse);
      expect(map['reward'], {
        'current_xp': 50,
        'traits': [
          {'name': 'Porządek', 'value': '+1'},
        ],
      });

      final roundTripped = Quest.fromMap('q1', map);
      expect(roundTripped.title, quest.title);
      expect(roundTripped.reward.currentXp, 50);
      expect(roundTripped.assignedToCharacterId, isNull);
    });

    test('toMap/fromMap round trip for a directly-assigned quest', () {
      const quest = Quest(
        id: 'q2',
        title: 'Ugotuj obiad',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Ala',
        assignedToCharacterId: 'c1',
        assignedToCharacterName: 'Grommash',
        assignedToEmail: 'grommash@example.com',
        status: QuestStatus.assigned,
        reward: ChangeSet(currentXp: 30),
        changeRequestId: null,
      );

      final map = quest.toMap();
      final roundTripped = Quest.fromMap('q2', map);
      expect(roundTripped.assignedToCharacterId, 'c1');
      expect(roundTripped.status, QuestStatus.assigned);
    });

    test('fromMap tolerates a missing reward map', () {
      final quest = Quest.fromMap('q3', {
        'title': 'Wynieś śmieci',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Ala',
        'status': 'open',
      });
      expect(quest.reward.isEmpty, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/quest_test.dart`
Expected: FAIL — `lib/models/quest.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/quest.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_request.dart';

String? _asString(Object? v) => v is String ? v : null;

enum QuestStatus {
  open,
  assigned,
  pendingReview,
  completed,
  failed,
  cancelled;

  String get wire => this == QuestStatus.pendingReview ? 'pending_review' : name;

  /// Anything unrecognised is treated as still-open: a quest nobody can act
  /// on is worse than one that shows up on the board again.
  static QuestStatus parse(Object? v) {
    for (final s in QuestStatus.values) {
      if (s.wire == v) return s;
    }
    return QuestStatus.open;
  }
}

class Quest {
  const Quest({
    required this.id,
    required this.title,
    this.description,
    required this.posterUid,
    required this.posterEmail,
    required this.posterName,
    this.assignedToCharacterId,
    this.assignedToCharacterName,
    this.assignedToEmail,
    required this.status,
    required this.reward,
    this.changeRequestId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String posterUid;
  final String posterEmail;
  final String posterName;
  final String? assignedToCharacterId;
  final String? assignedToCharacterName;
  final String? assignedToEmail;
  final QuestStatus status;

  /// XP delta and/or trait upserts — the exact same shape and semantics as
  /// a `ChangeRequest.changes`, just never carrying a `gold` delta.
  final ChangeSet reward;

  final String? changeRequestId;
  final DateTime? createdAt;

  static DateTime? _asDate(Object? v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  factory Quest.fromMap(String id, Map<String, dynamic> data) => Quest(
        id: id,
        title: _asString(data['title']) ?? '',
        description: _asString(data['description']),
        posterUid: _asString(data['posterUid']) ?? '',
        posterEmail: _asString(data['posterEmail']) ?? '',
        posterName: _asString(data['posterName']) ?? '',
        assignedToCharacterId: _asString(data['assignedToCharacterId']),
        assignedToCharacterName: _asString(data['assignedToCharacterName']),
        assignedToEmail: _asString(data['assignedToEmail']),
        status: QuestStatus.parse(data['status']),
        reward: data['reward'] is Map
            ? ChangeSet.fromMap(Map<String, dynamic>.from(data['reward'] as Map))
            : const ChangeSet(),
        changeRequestId: _asString(data['changeRequestId']),
        createdAt: _asDate(data['createdAt']),
      );

  /// `createdAt` is deliberately absent: the repository writes it as a
  /// server timestamp rather than trusting the device clock.
  Map<String, dynamic> toMap() => {
        'title': title,
        'posterUid': posterUid,
        'posterEmail': posterEmail,
        'posterName': posterName,
        if (description != null) 'description': description,
        if (assignedToCharacterId != null)
          'assignedToCharacterId': assignedToCharacterId,
        if (assignedToCharacterName != null)
          'assignedToCharacterName': assignedToCharacterName,
        if (assignedToEmail != null) 'assignedToEmail': assignedToEmail,
        'status': status.wire,
        'reward': reward.toMap(),
        if (changeRequestId != null) 'changeRequestId': changeRequestId,
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/quest_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/quest.dart test/models/quest_test.dart
git commit -m "feat: add Quest/QuestStatus model"
```

---

### Task 2: `QuestRosterEntry` model

**Files:**
- Create: `lib/models/quest_roster_entry.dart`
- Test: `test/models/quest_roster_entry_test.dart`

**Interfaces:**
- Produces: `class QuestRosterEntry { characterId, characterName, email }`, `factory QuestRosterEntry.fromMap(String id, Map<String, dynamic> data)`, `Map<String, dynamic> toMap()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/quest_roster_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/quest_roster_entry.dart';

void main() {
  test('toMap/fromMap round trip', () {
    const entry = QuestRosterEntry(
      characterId: 'c1',
      characterName: 'Grommash',
      email: 'grommash@example.com',
    );
    final map = entry.toMap();
    expect(map, {'characterName': 'Grommash', 'email': 'grommash@example.com'});

    final roundTripped = QuestRosterEntry.fromMap('c1', map);
    expect(roundTripped.characterId, 'c1');
    expect(roundTripped.characterName, 'Grommash');
    expect(roundTripped.email, 'grommash@example.com');
  });

  test('fromMap tolerates missing fields', () {
    final entry = QuestRosterEntry.fromMap('c2', const {});
    expect(entry.characterName, '');
    expect(entry.email, '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/quest_roster_entry_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/quest_roster_entry.dart
String? _asString(Object? v) => v is String ? v : null;

/// A thin, admin-curated public index of characters eligible for direct
/// quest assignment -- name/id/email only, never the character's stats. The
/// document id is always the character's own id.
class QuestRosterEntry {
  const QuestRosterEntry({
    required this.characterId,
    required this.characterName,
    required this.email,
  });

  final String characterId;
  final String characterName;
  final String email;

  factory QuestRosterEntry.fromMap(String id, Map<String, dynamic> data) =>
      QuestRosterEntry(
        characterId: id,
        characterName: _asString(data['characterName']) ?? '',
        email: _asString(data['email']) ?? '',
      );

  Map<String, dynamic> toMap() => {
        'characterName': characterName,
        'email': email,
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/quest_roster_entry_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/quest_roster_entry.dart test/models/quest_roster_entry_test.dart
git commit -m "feat: add QuestRosterEntry model"
```

---

### Task 3: `ChangeRequest` gains `questId`/`questTitle`

**Files:**
- Modify: `lib/models/change_request.dart:95-176`
- Test: `test/models/change_request_test.dart` (add cases; file already exists)

**Interfaces:**
- Produces: `ChangeRequest.questId` (`String?`), `ChangeRequest.questTitle` (`String?`), both optional constructor params, present in `fromMap`/`toMap` when set.

- [ ] **Step 1: Write the failing test**

Add to `test/models/change_request_test.dart` (inspect the file first for its existing `group`/helper style and match it):

```dart
test('toMap/fromMap round trip carries questId/questTitle when set', () {
  const request = ChangeRequest(
    id: 'r1',
    characterId: 'c1',
    characterName: 'Grommash',
    requesterUid: 'u1',
    requesterEmail: 'ala@example.com',
    status: ChangeRequestStatus.pending,
    changes: ChangeSet(currentXp: 50),
    questId: 'q1',
    questTitle: 'Posprzątaj garaż',
  );

  final map = request.toMap();
  expect(map['questId'], 'q1');
  expect(map['questTitle'], 'Posprzątaj garaż');

  final roundTripped = ChangeRequest.fromMap('r1', map);
  expect(roundTripped.questId, 'q1');
  expect(roundTripped.questTitle, 'Posprzątaj garaż');
});

test('questId/questTitle are absent when not a quest-originated request', () {
  const request = ChangeRequest(
    id: 'r2',
    characterId: 'c1',
    characterName: 'Grommash',
    requesterUid: 'u1',
    requesterEmail: 'ala@example.com',
    status: ChangeRequestStatus.pending,
    changes: ChangeSet(currentXp: 10),
  );
  expect(request.toMap().containsKey('questId'), isFalse);
  expect(request.questId, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/change_request_test.dart`
Expected: FAIL — `questId` is not a defined named parameter.

- [ ] **Step 3: Implement**

In `lib/models/change_request.dart`, add to the `ChangeRequest` constructor and fields (near `rejectionReason`):

```dart
    this.rejectionReason,
    this.questId,
    this.questTitle,
  });

  // ... existing fields ...

  /// Set only when this request was raised by completing a quest.
  final String? questId;

  /// Denormalised quest title, so the admin card and the requester's own
  /// history can show the link without an extra read.
  final String? questTitle;
```

In `fromMap`, add:

```dart
        rejectionReason: _asString(data['rejectionReason']),
        questId: _asString(data['questId']),
        questTitle: _asString(data['questTitle']),
      );
```

In `toMap`, add:

```dart
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (questId != null) 'questId': questId,
        if (questTitle != null) 'questTitle': questTitle,
      };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/change_request_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/change_request.dart test/models/change_request_test.dart
git commit -m "feat: link ChangeRequest back to the quest it came from"
```

---

### Task 4: `QuestRepository` — create + watch streams

**Files:**
- Create: `lib/data/quest_repository.dart`
- Test: `test/data/quest_repository_test.dart`

**Interfaces:**
- Consumes: `Quest`, `QuestStatus` (Task 1).
- Produces: `class QuestRepository(FirebaseFirestore db)` with `Future<void> create(Quest quest)`, `Stream<List<Quest>> watchOpen()`, `Stream<List<Quest>> watchAssignedTo(List<String> characterIds)`, `Stream<List<Quest>> watchPostedBy(String uid)`, `Stream<List<Quest>> watchLog()`. Later tasks (5, 6) add more methods to this same class.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/quest_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_repository.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

Quest _openQuest({String title = 'Posprzątaj garaż'}) => Quest(
      id: '',
      title: title,
      posterUid: 'u1',
      posterEmail: 'ala@example.com',
      posterName: 'Ala',
      status: QuestStatus.open,
      reward: const ChangeSet(currentXp: 50),
    );

void main() {
  test('create writes an open quest with a server timestamp', () async {
    final db = FakeFirebaseFirestore();
    await QuestRepository(db).create(_openQuest());

    final docs = await db.collection('quests').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.single.data();
    expect(data['status'], 'open');
    expect(data['title'], 'Posprzątaj garaż');
    expect(data['createdAt'], isNotNull);
  });

  test('watchOpen returns only open quests', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });

    final open = await repo.watchOpen().first;
    expect(open, hasLength(1));
    expect(open.single.title, 'Posprzątaj garaż');
  });

  test('watchAssignedTo filters by assignedToCharacterId', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'grommash@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });
    await db.collection('quests').add({
      'title': 'Wynieś śmieci',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c2',
      'status': 'assigned',
      'reward': {'current_xp': 15},
    });

    final mine = await QuestRepository(db).watchAssignedTo(['c1']).first;
    expect(mine, hasLength(1));
    expect(mine.single.title, 'Ugotuj obiad');
  });

  test('watchAssignedTo returns nothing for an empty character list', () async {
    final db = FakeFirebaseFirestore();
    final result = await QuestRepository(db).watchAssignedTo(const []).first;
    expect(result, isEmpty);
  });

  test('watchPostedBy filters by posterUid across all statuses', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    await db.collection('quests').add({
      'title': 'Zrób pranie',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'cancelled',
      'reward': {'current_xp': 5},
    });
    await db.collection('quests').add({
      'title': 'Nie moje',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 5},
    });

    final mine = await repo.watchPostedBy('u1').first;
    expect(mine, hasLength(2));
  });

  test('watchLog returns only terminal statuses', () async {
    final db = FakeFirebaseFirestore();
    for (final status in ['open', 'assigned', 'pending_review']) {
      await db.collection('quests').add({
        'title': 'Niekończące się $status',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Ala',
        'status': status,
        'reward': {'current_xp': 5},
      });
    }
    for (final status in ['completed', 'failed', 'cancelled']) {
      await db.collection('quests').add({
        'title': 'Zakończone $status',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Ala',
        'status': status,
        'reward': {'current_xp': 5},
      });
    }

    final log = await QuestRepository(db).watchLog().first;
    expect(log, hasLength(3));
    expect(log.every((q) => q.title.startsWith('Zakończone')), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/quest_repository_test.dart`
Expected: FAIL — `lib/data/quest_repository.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/quest_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quest.dart';

class QuestRepository {
  QuestRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _quests => _db.collection('quests');

  /// `createdAt` is written server-side rather than from the device clock,
  /// matching `ChangeRequestRepository.create`.
  Future<void> create(Quest quest) => _quests.add({
        ...quest.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Quest>> watchOpen() =>
      _watch(_quests.where('status', isEqualTo: QuestStatus.open.wire));

  /// The "Moje: przypisane do mnie" section and the assigned-to-me
  /// notification both watch this across *every* status the caller cares
  /// about (they filter client-side), since a taker may own more than one
  /// character. `whereIn` with an empty list throws in Firestore, so an
  /// empty roster short-circuits to an empty stream rather than querying.
  Stream<List<Quest>> watchAssignedTo(List<String> characterIds) {
    if (characterIds.isEmpty) return Stream.value(const []);
    return _watch(_quests.where('assignedToCharacterId', whereIn: characterIds));
  }

  /// Every status for quests this uid posted -- the "Moje: wystawione przeze
  /// mnie" section filters to `open` client-side, and the "quest taken"
  /// notification filters to `assigned` client-side.
  Stream<List<Quest>> watchPostedBy(String uid) =>
      _watch(_quests.where('posterUid', isEqualTo: uid));

  /// The global outcome feed -- every terminal status, visible to everyone.
  Stream<List<Quest>> watchLog() => _watch(_quests.where('status', whereIn: [
        QuestStatus.completed.wire,
        QuestStatus.failed.wire,
        QuestStatus.cancelled.wire,
      ]));

  Stream<List<Quest>> _watch(Query<Map<String, dynamic>> query) =>
      query.snapshots().map((snap) {
        final quests = snap.docs
            .map((d) {
              try {
                return Quest.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed quest ${d.id}: $e');
                return null;
              }
            })
            .whereType<Quest>()
            .toList();
        // Sorted client-side rather than with orderBy, same reasoning as
        // ChangeRequestRepository: a quest whose server timestamp has not
        // landed yet must not be dropped from the list.
        quests.sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return -1;
          if (bt == null) return 1;
          return bt.compareTo(at);
        });
        return quests;
      });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/quest_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/quest_repository.dart test/data/quest_repository_test.dart
git commit -m "feat: add QuestRepository create/watch"
```

---

### Task 5: `QuestRepository` — take / abandon / withdraw

**Files:**
- Modify: `lib/data/quest_repository.dart`
- Test: `test/data/quest_repository_test.dart` (add cases)

**Interfaces:**
- Produces: `class QuestNotOpen implements Exception` (Polish `toString`), `class QuestNotAssignedToCaller implements Exception` (Polish `toString`); `Future<void> take(Quest quest, {required String characterId, required String characterName, required String email})`, `Future<void> abandon(Quest quest)`, `Future<void> withdraw(Quest quest)`.

- [ ] **Step 1: Write the failing test**

Add to `test/data/quest_repository_test.dart`:

```dart
test('take assigns an open quest and sets the taker fields', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  final quest = (await repo.watchOpen().first).single;

  await repo.take(
    quest,
    characterId: 'c1',
    characterName: 'Grommash',
    email: 'ala@example.com',
  );

  final doc = await db.collection('quests').doc(quest.id).get();
  expect(doc.data()!['status'], 'assigned');
  expect(doc.data()!['assignedToCharacterId'], 'c1');
});

test('take throws QuestNotOpen on a quest already taken', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  final quest = (await repo.watchOpen().first).single;
  await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'a@example.com');

  expect(
    () => repo.take(quest, characterId: 'c2', characterName: 'Bob', email: 'b@example.com'),
    throwsA(isA<QuestNotOpen>()),
  );
});

test('abandon returns an assigned quest to open and clears the taker', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  var quest = (await repo.watchOpen().first).single;
  await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'a@example.com');
  quest = (await repo.watchAssignedTo(['c1']).first).single;

  await repo.abandon(quest);

  final doc = await db.collection('quests').doc(quest.id).get();
  expect(doc.data()!['status'], 'open');
  expect(doc.data()!.containsKey('assignedToCharacterId'), isFalse);
});

test('abandon throws QuestNotAssignedToCaller on a quest not currently assigned', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  final quest = (await repo.watchOpen().first).single;

  expect(() => repo.abandon(quest), throwsA(isA<QuestNotAssignedToCaller>()));
});

test('withdraw cancels an open quest', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  final quest = (await repo.watchOpen().first).single;

  await repo.withdraw(quest);

  final doc = await db.collection('quests').doc(quest.id).get();
  expect(doc.data()!['status'], 'cancelled');
});

test('withdraw throws QuestNotOpen on a quest already taken', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  final quest = (await repo.watchOpen().first).single;
  await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'a@example.com');

  expect(() => repo.withdraw(quest), throwsA(isA<QuestNotOpen>()));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/quest_repository_test.dart`
Expected: FAIL — `take`/`abandon`/`withdraw` are not defined.

- [ ] **Step 3: Write the implementation**

Add above the `QuestRepository` class:

```dart
/// Thrown when `take`/`withdraw` re-read the quest and it is no longer
/// `open` -- someone else took it, or it was withdrawn, since the caller's
/// copy was fetched. Mirrors `ChangeRequestNoLongerPending`.
class QuestNotOpen implements Exception {
  const QuestNotOpen();

  @override
  String toString() => 'To zadanie nie jest już dostępne';
}

/// Thrown when `abandon`/`markComplete` re-read the quest and it is no
/// longer `assigned` -- it was already abandoned, completed, or the caller
/// is stale.
class QuestNotAssignedToCaller implements Exception {
  const QuestNotAssignedToCaller();

  @override
  String toString() => 'To zadanie nie jest już przypisane';
}
```

Add to the `QuestRepository` class:

```dart
  Future<void> take(
    Quest quest, {
    required String characterId,
    required String characterName,
    required String email,
  }) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.open) {
        throw const QuestNotOpen();
      }
      tx.update(ref, {
        'status': QuestStatus.assigned.wire,
        'assignedToCharacterId': characterId,
        'assignedToCharacterName': characterName,
        'assignedToEmail': email,
      });
    });
  }

  Future<void> abandon(Quest quest) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.assigned) {
        throw const QuestNotAssignedToCaller();
      }
      tx.update(ref, {
        'status': QuestStatus.open.wire,
        'assignedToCharacterId': FieldValue.delete(),
        'assignedToCharacterName': FieldValue.delete(),
        'assignedToEmail': FieldValue.delete(),
      });
    });
  }

  Future<void> withdraw(Quest quest) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.open) {
        throw const QuestNotOpen();
      }
      tx.update(ref, {'status': QuestStatus.cancelled.wire});
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/quest_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/quest_repository.dart test/data/quest_repository_test.dart
git commit -m "feat: add quest take/abandon/withdraw transitions"
```

---

### Task 6: `QuestRepository.markComplete` — raises the linked `ChangeRequest`

**Files:**
- Modify: `lib/data/quest_repository.dart`
- Test: `test/data/quest_repository_test.dart` (add cases)

**Interfaces:**
- Consumes: `ChangeRequestStatus` from `lib/models/change_request.dart`.
- Produces: `Future<void> markComplete(Quest quest, {required String requesterUid, required String requesterEmail})` — writes a new `change_requests` doc (`changes` = `quest.reward`, `questId`, `questTitle`, no `reason`) and flips the quest to `pending_review` with `changeRequestId` set, in one transaction.

- [ ] **Step 1: Write the failing test**

Add to `test/data/quest_repository_test.dart`:

```dart
test('markComplete raises a linked change request and flips to pending_review', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  var quest = (await repo.watchOpen().first).single;
  await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'ala@example.com');
  quest = (await repo.watchAssignedTo(['c1']).first).single;

  await repo.markComplete(quest, requesterUid: 'u1', requesterEmail: 'ala@example.com');

  final questDoc = await db.collection('quests').doc(quest.id).get();
  expect(questDoc.data()!['status'], 'pending_review');
  final requestId = questDoc.data()!['changeRequestId'] as String;

  final requestDoc = await db.collection('change_requests').doc(requestId).get();
  final data = requestDoc.data()!;
  expect(data['status'], 'pending');
  expect(data['characterId'], 'c1');
  expect(data['characterName'], 'Grommash');
  expect(data['requesterUid'], 'u1');
  expect(data['changes'], {'current_xp': 50});
  expect(data['questId'], quest.id);
  expect(data['questTitle'], 'Posprzątaj garaż');
  expect(data.containsKey('reason'), isFalse);
});

test('markComplete throws QuestNotAssignedToCaller on a quest not assigned', () async {
  final db = FakeFirebaseFirestore();
  final repo = QuestRepository(db);
  await repo.create(_openQuest());
  final quest = (await repo.watchOpen().first).single;

  expect(
    () => repo.markComplete(quest, requesterUid: 'u1', requesterEmail: 'ala@example.com'),
    throwsA(isA<QuestNotAssignedToCaller>()),
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/quest_repository_test.dart`
Expected: FAIL — `markComplete` is not defined.

- [ ] **Step 3: Write the implementation**

Add `import '../models/change_request.dart' show ChangeRequestStatus;` to the top of `lib/data/quest_repository.dart`, and add the method to `QuestRepository`:

```dart
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('change_requests');

  /// Raises the change request an admin will review, and flips the quest to
  /// `pending_review` in the same transaction -- either both writes land or
  /// neither does. The request's `reason` is deliberately left unset: the
  /// link to its quest is carried by `questId`/`questTitle`, rendered as its
  /// own line by the admin screens, not smuggled into free text.
  Future<void> markComplete(
    Quest quest, {
    required String requesterUid,
    required String requesterEmail,
  }) async {
    final questRef = _quests.doc(quest.id);
    final requestRef = _requests.doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(questRef);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.assigned) {
        throw const QuestNotAssignedToCaller();
      }
      tx.set(requestRef, {
        'characterId': quest.assignedToCharacterId,
        'characterName': quest.assignedToCharacterName,
        'requesterUid': requesterUid,
        'requesterEmail': requesterEmail,
        'status': ChangeRequestStatus.pending.wire,
        'changes': quest.reward.toMap(),
        'questId': quest.id,
        'questTitle': quest.title,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(questRef, {
        'status': QuestStatus.pendingReview.wire,
        'changeRequestId': requestRef.id,
      });
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/quest_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/quest_repository.dart test/data/quest_repository_test.dart
git commit -m "feat: quest completion raises its linked change request"
```

---

### Task 7: `ChangeRequestRepository.accept`/`reject` flip the linked quest

**Files:**
- Modify: `lib/data/change_request_repository.dart:37-243`
- Test: `test/data/change_request_repository_test.dart` (add cases)

**Interfaces:**
- Consumes: `QuestStatus` from `lib/models/quest.dart`.
- No new public methods — `accept`/`reject`'s existing signatures are unchanged; they just do one more conditional write inside the same transaction.

- [ ] **Step 1: Write the failing test**

Add to `test/data/change_request_repository_test.dart` (match the file's existing helper/import style):

```dart
test('accept flips a linked quest to completed', () async {
  final db = FakeFirebaseFirestore();
  final questRef = await db.collection('quests').add({
    'title': 'Posprzątaj garaż',
    'posterUid': 'u1',
    'posterEmail': 'ala@example.com',
    'posterName': 'Ala',
    'assignedToCharacterId': 'c1',
    'status': 'pending_review',
    'reward': {'current_xp': 50},
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'current_xp': 10,
  });
  final request = _request(characterId: 'c1', changes: const ChangeSet(currentXp: 50));
  final repo = ChangeRequestRepository(db);
  await repo.create(ChangeRequest(
    id: '',
    characterId: request.characterId,
    characterName: request.characterName,
    requesterUid: request.requesterUid,
    requesterEmail: request.requesterEmail,
    status: ChangeRequestStatus.pending,
    changes: request.changes,
    questId: questRef.id,
    questTitle: 'Posprzątaj garaż',
  ));
  final saved = (await repo.watchPending().first).single;

  await repo.accept(saved, adminUid: 'admin1');

  final questDoc = await db.collection('quests').doc(questRef.id).get();
  expect(questDoc.data()!['status'], 'completed');
});

test('reject flips a linked quest to failed', () async {
  final db = FakeFirebaseFirestore();
  final questRef = await db.collection('quests').add({
    'title': 'Umyj okna',
    'posterUid': 'u1',
    'posterEmail': 'ala@example.com',
    'posterName': 'Ala',
    'assignedToCharacterId': 'c1',
    'status': 'pending_review',
    'reward': {'current_xp': 25},
  });
  final repo = ChangeRequestRepository(db);
  await repo.create(ChangeRequest(
    id: '',
    characterId: 'c1',
    characterName: 'Grommash',
    requesterUid: 'u1',
    requesterEmail: 'ala@example.com',
    status: ChangeRequestStatus.pending,
    changes: const ChangeSet(currentXp: 25),
    questId: questRef.id,
    questTitle: 'Umyj okna',
  ));
  final saved = (await repo.watchPending().first).single;

  await repo.reject(saved, adminUid: 'admin1');

  final questDoc = await db.collection('quests').doc(questRef.id).get();
  expect(questDoc.data()!['status'], 'failed');
});

test('accept on a request with no questId does not touch /quests', () async {
  final db = FakeFirebaseFirestore();
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'current_xp': 10,
  });
  final repo = ChangeRequestRepository(db);
  await repo.create(_request(characterId: 'c1'));
  final saved = (await repo.watchPending().first).single;

  await repo.accept(saved, adminUid: 'admin1');

  expect((await db.collection('quests').get()).docs, isEmpty);
});
```

(`_request` here is the file's existing helper — extend its signature with an optional `characterId` param if it does not already accept one; check the existing helper before editing.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: FAIL — the quest document is never updated.

- [ ] **Step 3: Write the implementation**

Add `import '../models/quest.dart' show QuestStatus;` to the top of `lib/data/change_request_repository.dart`. In `accept`, right before `tx.update(requestRef, {...})`'s closing, add the conditional quest flip (using the *re-read* request data, not the caller's possibly-stale `request` object, matching the file's existing "re-read is the point" philosophy):

```dart
    await _db.runTransaction((tx) async {
      final requestData = await _readPending(tx, requestRef);

      final characterSnap = await tx.get(characterRef);
      final character = characterSnap.data();
      if (character == null) {
        throw const ChangeRequestCharacterGone();
      }

      tx.update(characterRef, _applyTo(character, applied));
      tx.update(requestRef, {
        'status': ChangeRequestStatus.accepted.wire,
        'appliedChanges': applied.toMap(),
        'decidedBy': adminUid,
        'decidedAt': FieldValue.serverTimestamp(),
      });

      final questId = requestData['questId'];
      if (questId is String) {
        tx.update(_db.collection('quests').doc(questId), {
          'status': QuestStatus.completed.wire,
        });
      }
    });
```

And in `reject`:

```dart
  Future<void> reject(
    ChangeRequest request, {
    required String adminUid,
    String? reason,
  }) async {
    final requestRef = _requests.doc(request.id);
    await _db.runTransaction((tx) async {
      final requestData = await _readPending(tx, requestRef);
      tx.update(requestRef, {
        'status': ChangeRequestStatus.rejected.wire,
        'decidedBy': adminUid,
        'decidedAt': FieldValue.serverTimestamp(),
        'rejectionReason': ?reason,
      });

      final questId = requestData['questId'];
      if (questId is String) {
        tx.update(_db.collection('quests').doc(questId), {
          'status': QuestStatus.failed.wire,
        });
      }
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/change_request_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/change_request_repository.dart test/data/change_request_repository_test.dart
git commit -m "feat: accept/reject flip a quest-originated request's quest"
```

---

### Task 8: `QuestRosterRepository`

**Files:**
- Create: `lib/data/quest_roster_repository.dart`
- Test: `test/data/quest_roster_repository_test.dart`

**Interfaces:**
- Produces: `class QuestRosterRepository(FirebaseFirestore db)` — `Stream<List<QuestRosterEntry>> watchRoster()`, `Future<void> add({required String characterId, required String characterName, required String email})`, `Future<void> remove(String characterId)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/quest_roster_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_roster_repository.dart';

void main() {
  test('add writes a roster entry keyed by characterId', () async {
    final db = FakeFirebaseFirestore();
    await QuestRosterRepository(db).add(
      characterId: 'c1',
      characterName: 'Grommash',
      email: 'Grommash@Example.com',
    );

    final doc = await db.collection('quest_roster').doc('c1').get();
    expect(doc.data()!['characterName'], 'Grommash');
    // Lowercased at write time so the create-rule email cross-check on
    // /quests (which compares lowercased strings) can match it directly.
    expect(doc.data()!['email'], 'grommash@example.com');
  });

  test('remove deletes the entry', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRosterRepository(db);
    await repo.add(characterId: 'c1', characterName: 'Grommash', email: 'g@example.com');

    await repo.remove('c1');

    final doc = await db.collection('quest_roster').doc('c1').get();
    expect(doc.exists, isFalse);
  });

  test('watchRoster returns entries sorted by character name', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRosterRepository(db);
    await repo.add(characterId: 'c1', characterName: 'Zorak', email: 'z@example.com');
    await repo.add(characterId: 'c2', characterName: 'Ala', email: 'a@example.com');

    final roster = await repo.watchRoster().first;
    expect(roster.map((e) => e.characterName), ['Ala', 'Zorak']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/quest_roster_repository_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/quest_roster_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quest_roster_entry.dart';

class QuestRosterRepository {
  QuestRosterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _roster =>
      _db.collection('quest_roster');

  Stream<List<QuestRosterEntry>> watchRoster() => _roster.snapshots().map((snap) {
        final entries = snap.docs
            .map((d) {
              try {
                return QuestRosterEntry.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed quest roster entry ${d.id}: $e');
                return null;
              }
            })
            .whereType<QuestRosterEntry>()
            .toList();
        entries.sort((a, b) => a.characterName.compareTo(b.characterName));
        return entries;
      });

  /// The doc id is always the character's own id -- a `set` here both adds a
  /// new entry and updates an existing one's denormalised name/email.
  Future<void> add({
    required String characterId,
    required String characterName,
    required String email,
  }) =>
      _roster.doc(characterId).set(
        QuestRosterEntry(
          characterId: characterId,
          characterName: characterName,
          email: email.toLowerCase(),
        ).toMap(),
      );

  Future<void> remove(String characterId) => _roster.doc(characterId).delete();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/quest_roster_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/quest_roster_repository.dart test/data/quest_roster_repository_test.dart
git commit -m "feat: add QuestRosterRepository"
```

---

### Task 9: Firestore rules for `quests` and `quest_roster`

**Files:**
- Modify: `firestore.rules:1-72`
- Test: `tools/rules-test/rules.test.mjs` (add cases)

**Interfaces:**
- No Dart interface — this task only changes the deployed rules and their tests. Field names below must match `Quest.toMap()`/`QuestRosterEntry.toMap()` exactly (Tasks 1–2).

- [ ] **Step 1: Write the failing tests**

Open `tools/rules-test/rules.test.mjs` first and match its existing style (`env.authenticatedContext(uid).firestore()`, `assertSucceeds`/`assertFails`, `env.withSecurityRulesDisabled(...)` for fixture setup that must bypass the rules being tested). Append near the end of the file, before the closing, self-contained tests that seed their own fixtures rather than relying on the shared `seedCharacters()` (which was written for the existing `characters`/`change_requests` tests, not this feature):

```js
test('any signed-in user may read an open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q1'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const db = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(db, 'quests/q1')));
});

test('a user may post an open board quest in their own name', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'quests/q2'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30 },
    })
  );
});

test('a user may not post a quest in somebody else\'s name', async () => {
  const db = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q3'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30 },
    })
  );
});

test('direct assignment requires the target character to be on the quest roster', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q4'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'not-on-roster',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'grommash@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    })
  );
});

test('direct assignment succeeds once the target is on the quest roster', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quest_roster/c1'), {
      characterName: 'Grommash',
      email: 'grommash@example.com',
    });
  });
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'quests/q5'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c1',
      assignedToCharacterName: 'Grommash',
      assignedToEmail: 'grommash@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    })
  );
});

test('a quest reward may not carry a gold delta', async () => {
  const db = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertFails(
    setDoc(doc(db, 'quests/q6'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 30, gold: 5 },
    })
  );
});

test('taking an open quest requires the taker to own the target character', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q7'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
    await setDoc(doc(ctx.firestore(), 'characters/c-bob'), {
      name: 'Bob the Bold',
      email: 'bob@example.com',
    });
  });
  const db = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(
    updateDoc(doc(db, 'quests/q7'), {
      status: 'assigned',
      assignedToCharacterId: 'c-bob',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'mallory@example.com',
    })
  );
});

test('taking an open quest for your own character succeeds', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q8'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
    await setDoc(doc(ctx.firestore(), 'characters/c-bob2'), {
      name: 'Bob the Bold',
      email: 'bob@example.com',
    });
  });
  const db = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'quests/q8'), {
      status: 'assigned',
      assignedToCharacterId: 'c-bob2',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
    })
  );
});

test('only the poster may withdraw an open quest', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q9'), {
      title: 'Posprzątaj garaż',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      status: 'open',
      reward: { current_xp: 50 },
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(updateDoc(doc(mallory, 'quests/q9'), { status: 'cancelled' }));

  const alice = env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
  await assertSucceeds(updateDoc(doc(alice, 'quests/q9'), { status: 'cancelled' }));
});

test('only the current holder may abandon or mark an assigned quest complete', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'quests/q10'), {
      title: 'Ugotuj obiad',
      posterUid: 'alice',
      posterEmail: 'alice@example.com',
      posterName: 'Alice',
      assignedToCharacterId: 'c-bob3',
      assignedToCharacterName: 'Bob the Bold',
      assignedToEmail: 'bob@example.com',
      status: 'assigned',
      reward: { current_xp: 30 },
    });
  });
  const mallory = env.authenticatedContext('mallory', { email: 'mallory@example.com' }).firestore();
  await assertFails(updateDoc(doc(mallory, 'quests/q10'), { status: 'pending_review' }));

  const bob = env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
  await assertSucceeds(updateDoc(doc(bob, 'quests/q10'), { status: 'pending_review' }));
});

test('only an admin may write to quest_roster', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin1'), { admin: true });
  });
  const mallory = env.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(mallory, 'quest_roster/c1'), { characterName: 'Grommash', email: 'g@example.com' })
  );

  const admin = env.authenticatedContext('admin1').firestore();
  await assertSucceeds(
    setDoc(doc(admin, 'quest_roster/c1'), { characterName: 'Grommash', email: 'g@example.com' })
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd tools/rules-test && npm test`
Expected: FAIL — no `match /quests/` or `match /quest_roster/` block exists yet.

- [ ] **Step 3: Write the rules**

Add to `firestore.rules`, inside `service cloud.firestore { match /databases/{database}/documents { ... } }`, after the existing `change_requests` block:

```
    match /quests/{questId} {
      // Board and log are visible to everyone signed in.
      allow read: if isAuthenticated();

      // Posted in your own name, either open with no assignment, or
      // assigned directly to a character that is on the public roster
      // (quest_roster) -- never a raw gold delta.
      allow create: if isAuthenticated()
                    && request.resource.data.posterUid == request.auth.uid
                    && request.resource.data.posterEmail.lower() == request.auth.token.email.lower()
                    && request.resource.data.reward.keys().hasAny(['current_xp', 'traits'])
                    && !('gold' in request.resource.data.reward)
                    && (
                      (request.resource.data.status == 'open'
                        && !('assignedToCharacterId' in request.resource.data))
                      ||
                      (request.resource.data.status == 'assigned'
                        && exists(/databases/$(database)/documents/quest_roster/$(request.resource.data.assignedToCharacterId))
                        && get(/databases/$(database)/documents/quest_roster/$(request.resource.data.assignedToCharacterId))
                             .data.email.lower() == request.resource.data.assignedToEmail.lower())
                    );

      allow update: if isAdmin()
                    // take: open -> assigned, by the taker, for their own character
                    || (isAuthenticated()
                        && resource.data.status == 'open'
                        && request.resource.data.status == 'assigned'
                        && request.resource.data.diff(resource.data).affectedKeys()
                             .hasOnly(['status', 'assignedToCharacterId', 'assignedToCharacterName', 'assignedToEmail'])
                        && request.resource.data.assignedToEmail.lower() == request.auth.token.email.lower()
                        && get(/databases/$(database)/documents/characters/$(request.resource.data.assignedToCharacterId))
                             .data.email.lower() == request.auth.token.email.lower())
                    // abandon: assigned -> open, by the current holder
                    || (isAuthenticated()
                        && resource.data.status == 'assigned'
                        && request.resource.data.status == 'open'
                        && resource.data.assignedToEmail.lower() == request.auth.token.email.lower()
                        && request.resource.data.diff(resource.data).affectedKeys()
                             .hasOnly(['status', 'assignedToCharacterId', 'assignedToCharacterName', 'assignedToEmail']))
                    // withdraw: open -> cancelled, by the poster
                    || (isAuthenticated()
                        && resource.data.status == 'open'
                        && request.resource.data.status == 'cancelled'
                        && resource.data.posterUid == request.auth.uid
                        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']))
                    // mark complete: assigned -> pending_review, by the current holder
                    || (isAuthenticated()
                        && resource.data.status == 'assigned'
                        && request.resource.data.status == 'pending_review'
                        && resource.data.assignedToEmail.lower() == request.auth.token.email.lower()
                        && request.resource.data.diff(resource.data).affectedKeys()
                             .hasOnly(['status', 'changeRequestId']));

      allow delete: if false;
    }

    match /quest_roster/{characterId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tools/rules-test && npm test`
Expected: PASS

- [ ] **Step 5: Deploy note and commit**

These rules are not live until deployed (`firebase deploy --only firestore:rules`); that is out of scope for this task (matches how `firestore.rules` changes are handled elsewhere in this repo — deployment is a manual release step, not part of the test suite).

```bash
git add firestore.rules tools/rules-test/rules.test.mjs
git commit -m "feat: add Firestore rules for quests and quest_roster"
```

---

### Task 10: Quest providers

**Files:**
- Create: `lib/providers/quest_providers.dart`
- Test: `test/providers/quest_providers_test.dart`

**Interfaces:**
- Consumes: `appUserProvider` (`lib/providers/auth_providers.dart`), `charactersProvider` (`lib/providers/character_providers.dart`), `firestoreProvider`.
- Produces: `questRepositoryProvider`, `questRosterRepositoryProvider`, `myOwnCharacterIdsProvider` (`Provider<List<String>>`), `openQuestsProvider`, `myAssignedQuestsProvider`, `myPostedQuestsProvider`, `questLogProvider` (all `StreamProvider<List<Quest>>`), `questRosterProvider` (`StreamProvider<List<QuestRosterEntry>>`).

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/quest_providers_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/providers/quest_providers.dart';

Future<ProviderContainer> _containerFor(FakeFirebaseFirestore db) async {
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
  test('myOwnCharacterIdsProvider returns only the signed-in user\'s own characters', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('characters').add({'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': []});
    await db.collection('characters').add({'name': 'Nie moje', 'email': 'bob@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': []});

    final container = await _containerFor(db);
    container.listen(myOwnCharacterIdsProvider, (_, _) {});
    // charactersProvider must resolve first for the character-derived
    // provider to see real data.
    container.listen(myAssignedQuestsProvider, (_, _) {});
    await container.read(myAssignedQuestsProvider.future);

    expect(container.read(myOwnCharacterIdsProvider), hasLength(1));
  });

  test('openQuestsProvider streams open quests once signed in', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });

    final container = await _containerFor(db);
    container.listen(openQuestsProvider, (_, _) {});
    final quests = await container.read(openQuestsProvider.future);

    expect(quests, hasLength(1));
    expect(quests.single.title, 'Posprzątaj garaż');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/quest_providers_test.dart`
Expected: FAIL — `lib/providers/quest_providers.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/providers/quest_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_providers.dart';
import '../data/quest_repository.dart';
import '../data/quest_roster_repository.dart';
import '../models/quest.dart';
import '../models/quest_roster_entry.dart';
import 'auth_providers.dart';
import 'character_providers.dart';

final questRepositoryProvider = Provider<QuestRepository>(
  (ref) => QuestRepository(ref.watch(firestoreProvider)),
);

final questRosterRepositoryProvider = Provider<QuestRosterRepository>(
  (ref) => QuestRosterRepository(ref.watch(firestoreProvider)),
);

/// The signed-in user's own characters, by id -- an admin viewing the whole
/// roster still only ever takes/is assigned quests for their own, same
/// reasoning as HomeScreen's `ownsACharacter`.
final myOwnCharacterIdsProvider = Provider<List<String>>((ref) {
  final user = ref.watch(appUserProvider).value;
  final feed = ref.watch(charactersProvider).value;
  if (user == null || feed == null) return const [];
  final email = user.email.toLowerCase();
  return [
    for (final c in feed.characters)
      if (c.email.toLowerCase() == email) c.id,
  ];
});

/// The open board. Readable by any signed-in user (see firestore.rules), so
/// this only gates on being signed in at all, unlike the admin-only change
/// request queue.
final openQuestsProvider = StreamProvider<List<Quest>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <Quest>[];
    return;
  }
  yield* ref.watch(questRepositoryProvider).watchOpen();
});

final myAssignedQuestsProvider = StreamProvider<List<Quest>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <Quest>[];
    return;
  }
  final ids = ref.watch(myOwnCharacterIdsProvider);
  if (ids.isEmpty) {
    yield const <Quest>[];
    return;
  }
  yield* ref.watch(questRepositoryProvider).watchAssignedTo(ids);
});

final myPostedQuestsProvider = StreamProvider<List<Quest>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <Quest>[];
    return;
  }
  yield* ref.watch(questRepositoryProvider).watchPostedBy(user.uid);
});

final questLogProvider = StreamProvider<List<Quest>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <Quest>[];
    return;
  }
  yield* ref.watch(questRepositoryProvider).watchLog();
});

final questRosterProvider = StreamProvider<List<QuestRosterEntry>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <QuestRosterEntry>[];
    return;
  }
  yield* ref.watch(questRosterRepositoryProvider).watchRoster();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/quest_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/providers/quest_providers.dart test/providers/quest_providers_test.dart
git commit -m "feat: add quest providers"
```

---

### Task 11: Quest notifications

**Files:**
- Create: `lib/data/quest_notifications.dart`
- Create: `lib/data/quest_notification_repository.dart`
- Create: `lib/providers/quest_notification_providers.dart`
- Test: `test/data/quest_notifications_test.dart`
- Test: `test/providers/quest_notification_providers_test.dart`

**Interfaces:**
- Consumes: `changeRequestNotificationServiceProvider` (`lib/providers/change_request_notification_providers.dart`, unchanged — reused as-is, it is already message-agnostic), `openQuestsProvider`/`myAssignedQuestsProvider`/`myPostedQuestsProvider` (Task 10).
- Produces: `class IdDiff<T> { toNotify, notifiedIds }`, `IdDiff<T> diffNewIds<T>({required List<T> items, required String Function(T) idOf, required Set<String>? previouslyNotified})`; `class QuestNotificationRepository` with three independent load/save pairs (open/assigned/taken baselines); `final questNotificationsProvider = Provider<void>(...)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/quest_notifications_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_notifications.dart';

void main() {
  test('first-ever check seeds the baseline silently', () {
    final diff = diffNewIds<int>(
      items: [1, 2, 3],
      idOf: (i) => '$i',
      previouslyNotified: null,
    );
    expect(diff.toNotify, isEmpty);
    expect(diff.notifiedIds, {'1', '2', '3'});
  });

  test('only newly-appearing ids are notified', () {
    final diff = diffNewIds<int>(
      items: [1, 2, 3],
      idOf: (i) => '$i',
      previouslyNotified: {'1'},
    );
    expect(diff.toNotify, [2, 3]);
    expect(diff.notifiedIds, {'1', '2', '3'});
  });

  test('an id that leaves the set is dropped, so it notifies again if it returns', () {
    final diff = diffNewIds<int>(
      items: [1],
      idOf: (i) => '$i',
      previouslyNotified: {'1', '2'},
    );
    expect(diff.toNotify, isEmpty);
    expect(diff.notifiedIds, {'1'});
  });
}
```

`questNotificationsProvider` is a plain `Provider<void>` (not itself awaitable), so — exactly like `test/providers/change_request_notification_providers_test.dart` does for `changeRequestNotificationsProvider` — settle its first reaction by awaiting the *watched stream provider's* `.future` and then one `Future<void>.delayed(Duration.zero)` before asserting:

```dart
// test/providers/quest_notification_providers_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notification_service.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/providers/change_request_notification_providers.dart';
import 'package:liferpg/providers/quest_notification_providers.dart';
import 'package:liferpg/providers/quest_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationService implements ChangeRequestNotificationService {
  final shown = <String>[];

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown.add(id);
  }
}

Future<ProviderContainer> _containerFor(
  FakeFirebaseFirestore db, {
  required String uid,
  required String email,
  required FakeNotificationService service,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: email),
    )),
    sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
    changeRequestNotificationServiceProvider.overrideWithValue(service),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a new open board quest from someone else notifies once', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});

    await container.read(openQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(service.shown, isEmpty);

    final questRef = await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, contains('quest_open_${questRef.id}'));
  });

  test('a poster is not notified about their own board posting', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(openQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    await db.collection('quests').add({
      'title': 'Zrób pranie',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'open',
      'reward': {'current_xp': 20},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, isEmpty);
  });

  test('a quest assigned directly to my character notifies me', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('characters').doc('c1').set({
      'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(myAssignedQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    final questRef = await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, contains('quest_assigned_${questRef.id}'));
  });

  test('a board quest I posted being taken notifies me', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final questRef = await db.collection('quests').add({
      'title': 'Wynieś śmieci',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'open',
      'reward': {'current_xp': 15},
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(myPostedQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    await questRef.update({
      'status': 'assigned',
      'assignedToCharacterId': 'c2',
      'assignedToCharacterName': 'Bob the Bold',
      'assignedToEmail': 'bob@example.com',
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, contains('quest_taken_${questRef.id}'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/quest_notifications_test.dart test/providers/quest_notification_providers_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/quest_notifications.dart
/// Which of `items` are newly present since the last check, and the id set
/// to persist afterwards. Generic over three quest events that all share
/// the exact same "notify on newly-appearing id, seed silently on the first
/// ever check" shape that `diffPendingRequests` established for change
/// requests -- kept as one generic helper here instead of three near-copies.
class IdDiff<T> {
  const IdDiff({required this.toNotify, required this.notifiedIds});

  final List<T> toNotify;
  final Set<String> notifiedIds;
}

IdDiff<T> diffNewIds<T>({
  required List<T> items,
  required String Function(T) idOf,
  required Set<String>? previouslyNotified,
}) {
  final currentIds = items.map(idOf).toSet();
  if (previouslyNotified == null) {
    return IdDiff(toNotify: const [], notifiedIds: currentIds);
  }
  final toNotify = items.where((i) => !previouslyNotified.contains(idOf(i))).toList();
  return IdDiff(toNotify: toNotify, notifiedIds: currentIds);
}
```

```dart
// lib/data/quest_notification_repository.dart
import 'package:shared_preferences/shared_preferences.dart';

/// On-device, per-uid baselines for the three quest notification events,
/// same shape and same reasoning as ChangeRequestNotificationRepository: a
/// `null` load means "no baseline yet for this uid", so the caller seeds
/// silently instead of flooding notifications for quests that already
/// existed before this device ever checked.
class QuestNotificationRepository {
  QuestNotificationRepository(this._prefs);

  final SharedPreferences _prefs;

  String _openKey(String uid) => 'notified_open_quests_$uid';
  String _assignedKey(String uid) => 'notified_assigned_quests_$uid';
  String _takenKey(String uid) => 'notified_taken_quests_$uid';

  Set<String>? loadNotifiedOpenIds(String uid) =>
      _prefs.getStringList(_openKey(uid))?.toSet();
  Future<void> saveNotifiedOpenIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_openKey(uid), ids.toList());

  Set<String>? loadNotifiedAssignedIds(String uid) =>
      _prefs.getStringList(_assignedKey(uid))?.toSet();
  Future<void> saveNotifiedAssignedIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_assignedKey(uid), ids.toList());

  Set<String>? loadNotifiedTakenIds(String uid) =>
      _prefs.getStringList(_takenKey(uid))?.toSet();
  Future<void> saveNotifiedTakenIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_takenKey(uid), ids.toList());
}
```

```dart
// lib/providers/quest_notification_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quest_notification_repository.dart';
import '../data/quest_notifications.dart';
import '../data/shared_preferences_provider.dart';
import '../models/quest.dart';
import 'auth_providers.dart';
import 'change_request_notification_providers.dart';
import 'quest_providers.dart';

final questNotificationRepositoryProvider = Provider<QuestNotificationRepository>(
  (ref) => QuestNotificationRepository(ref.watch(sharedPreferencesProvider)),
);

/// Watched once (from AuthGate, alongside changeRequestNotificationsProvider)
/// to keep it alive for the session. Reuses
/// changeRequestNotificationServiceProvider -- it is already a thin,
/// message-agnostic "post a system-tray notification" seam, so quests don't
/// need a service of their own.
final questNotificationsProvider = Provider<void>((ref) {
  ref.listen(openQuestsProvider, (previous, next) {
    final open = next.value;
    final user = ref.read(appUserProvider).value;
    if (open == null || user == null) return;
    // Never notify a poster about their own posting.
    final fromOthers = open.where((q) => q.posterUid != user.uid).toList();

    final repo = ref.read(questNotificationRepositoryProvider);
    final diff = diffNewIds(
      items: fromOthers,
      idOf: (Quest q) => q.id,
      previouslyNotified: repo.loadNotifiedOpenIds(user.uid),
    );
    repo.saveNotifiedOpenIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final quest in diff.toNotify) {
      service.show(
        id: 'quest_open_${quest.id}',
        title: 'Nowe zadanie na tablicy',
        body: quest.title,
        payload: 'quest_board',
      );
    }
  });

  ref.listen(myAssignedQuestsProvider, (previous, next) {
    final assigned =
        next.value?.where((q) => q.status == QuestStatus.assigned).toList();
    final user = ref.read(appUserProvider).value;
    if (assigned == null || user == null) return;

    final repo = ref.read(questNotificationRepositoryProvider);
    final diff = diffNewIds(
      items: assigned,
      idOf: (Quest q) => q.id,
      previouslyNotified: repo.loadNotifiedAssignedIds(user.uid),
    );
    repo.saveNotifiedAssignedIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final quest in diff.toNotify) {
      service.show(
        id: 'quest_assigned_${quest.id}',
        title: 'Przydzielono Ci zadanie',
        body: quest.title,
        payload: 'my_quests',
      );
    }
  });

  ref.listen(myPostedQuestsProvider, (previous, next) {
    final taken =
        next.value?.where((q) => q.status == QuestStatus.assigned).toList();
    final user = ref.read(appUserProvider).value;
    if (taken == null || user == null) return;

    final repo = ref.read(questNotificationRepositoryProvider);
    final diff = diffNewIds(
      items: taken,
      idOf: (Quest q) => q.id,
      previouslyNotified: repo.loadNotifiedTakenIds(user.uid),
    );
    repo.saveNotifiedTakenIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final quest in diff.toNotify) {
      service.show(
        id: 'quest_taken_${quest.id}',
        title: 'Ktoś podjął Twoje zadanie',
        body: quest.title,
        payload: 'my_quests',
      );
    }
  });
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/quest_notifications_test.dart test/providers/quest_notification_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Wire into `AuthGate` and commit**

In `lib/main.dart`, add the import and, right after line 96 (`ref.watch(changeRequestNotificationsProvider);`):

```dart
            ref.watch(changeRequestNotificationsProvider);
            ref.watch(questNotificationsProvider);
```

```bash
git add lib/data/quest_notifications.dart lib/data/quest_notification_repository.dart \
        lib/providers/quest_notification_providers.dart lib/main.dart \
        test/data/quest_notifications_test.dart test/providers/quest_notification_providers_test.dart
git commit -m "feat: add quest notifications"
```

---

### Task 12: FAB speed-dial

**Files:**
- Modify: `lib/features/home/home_screen.dart:169-185`
- Test: `test/features/home_screen_test.dart` (add cases)

**Interfaces:**
- Consumes: `QuestsScreen`. Task 14 (later in this plan) replaces this task's stub with the real tabbed screen; the stub only needs a `const QuestsScreen({super.key})` constructor, so no interface changes ripple back to this task.
- Produces: `Key('quest-fab')` (the main button), `Key('quest-fab-quests')`, `Key('quest-fab-change-request')` (the two revealed mini-FABs).

- [ ] **Step 1: Write the failing test**

Add to `test/features/home_screen_test.dart`:

```dart
testWidgets('the FAB opens a speed-dial with quests and change-request destinations', (tester) async {
  await pumpHome(tester, await seed());

  expect(find.byKey(const Key('quest-fab-quests')), findsNothing);
  await tester.tap(find.byKey(const Key('quest-fab')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('quest-fab-quests')), findsOneWidget);
  expect(find.byKey(const Key('quest-fab-change-request')), findsOneWidget);

  await tester.tap(find.byKey(const Key('quest-fab-change-request')));
  await tester.pumpAndSettle();
  expect(find.byType(NewChangeRequestScreen), findsOneWidget);
});

testWidgets('the quests destination opens QuestsScreen', (tester) async {
  await pumpHome(tester, await seed());
  await tester.tap(find.byKey(const Key('quest-fab')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('quest-fab-quests')));
  await tester.pumpAndSettle();

  expect(find.byType(QuestsScreen), findsOneWidget);
});
```

Add `import 'package:liferpg/features/quests/quests_screen.dart';` to the test file's imports.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home_screen_test.dart`
Expected: FAIL — `quest-fab` key does not exist yet, and `lib/features/quests/quests_screen.dart` does not exist yet either. Create a minimal stub now:

```dart
// lib/features/quests/quests_screen.dart
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(title: const Text('Zadania')),
        body: const SizedBox(),
      );
}
```

Task 14 replaces this file's contents with the real tabbed screen; the constructor stays the same, so this task's tests keep passing.

- [ ] **Step 3: Write the implementation**

Replace the `floatingActionButton` in `lib/features/home/home_screen.dart` (currently lines 169–185):

```dart
      floatingActionButton:
          ownsACharacter ? _QuestFab(key: const Key('quest-fab')) : null,
```

Add the `_QuestFab` widget to the same file (a `StatefulWidget` since it tracks open/closed state):

```dart
/// The FAB rotates into a close icon and reveals two labeled mini-FABs
/// above it -- Zadania (the quest board/moje/dziennik screen) and the
/// existing change-request form.
class _QuestFab extends StatefulWidget {
  const _QuestFab({super.key});

  @override
  State<_QuestFab> createState() => _QuestFabState();
}

class _QuestFabState extends State<_QuestFab> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  void _navigate(BuildContext context, Widget screen) {
    setState(() => _open = false);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Widget _miniFab({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: parchmentLight,
                border: Border.all(color: crimson),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 10,
                  letterSpacing: 1,
                  color: inkHeading,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              key: key,
              heroTag: key.toString(),
              backgroundColor: crimsonDeep,
              foregroundColor: parchmentLight,
              shape: const CircleBorder(side: BorderSide(color: goldBorder)),
              onPressed: onPressed,
              child: Icon(icon),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _miniFab(
            key: const Key('quest-fab-quests'),
            label: 'Zadania',
            icon: Icons.checklist,
            onPressed: () => _navigate(context, const QuestsScreen()),
          ),
          _miniFab(
            key: const Key('quest-fab-change-request'),
            label: 'Prośba o zmianę',
            icon: Icons.edit_note,
            onPressed: () => _navigate(context, const NewChangeRequestScreen()),
          ),
        ],
        FloatingActionButton(
          tooltip: _open ? 'Zamknij' : 'Dodaj',
          backgroundColor: crimson,
          foregroundColor: parchmentLight,
          shape: const CircleBorder(side: BorderSide(color: goldBorder)),
          onPressed: _toggle,
          child: Icon(_open ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}
```

Add `import '../quests/quests_screen.dart';` to the top of `home_screen.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_screen.dart test/features/home_screen_test.dart lib/features/quests/quests_screen.dart
git commit -m "feat: turn the home FAB into a quests/change-request speed-dial"
```

---

### Task 13: `QuestCard` — the shared ornamental quest card

**Files:**
- Create: `lib/features/quests/quest_card.dart`
- Test: `test/features/quest_card_test.dart`

**Interfaces:**
- Consumes: `Quest` (Task 1).
- Produces: `class QuestCard extends StatelessWidget` — `{ required Quest quest, String? posterOrHolderLine, List<Widget> actions = const [], Widget? statusBadge }`. Callers (Tasks 14–16) decide the caption line, the action buttons, and any status badge; the card itself only renders the ornamental frame, title, reward pills, and whatever is handed to it. This keeps board/moje/dziennik variants out of the card and in their own screens.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/quest_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/quests/quest_card.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

const _quest = Quest(
  id: 'q1',
  title: 'Posprzątaj garaż',
  posterUid: 'u1',
  posterEmail: 'ala@example.com',
  posterName: 'Ala',
  status: QuestStatus.open,
  reward: ChangeSet(currentXp: 50, traits: [TraitChange(name: 'Porządek', value: '+1')]),
);

void main() {
  testWidgets('renders the title, reward pills, caption, and actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuestCard(
          quest: _quest,
          posterOrHolderLine: 'Wystawione przez: Ala',
          actions: [TextButton(key: const Key('take'), onPressed: () {}, child: const Text('Podejmij'))],
        ),
      ),
    ));

    expect(find.text('Posprzątaj garaż'), findsOneWidget);
    expect(find.textContaining('+50 XP'), findsOneWidget);
    expect(find.textContaining('Porządek'), findsOneWidget);
    expect(find.text('Wystawione przez: Ala'), findsOneWidget);
    expect(find.byKey(const Key('take')), findsOneWidget);
  });

  testWidgets('renders a status badge when given one and no actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuestCard(
          quest: _quest,
          statusBadge: const Text('OCZEKUJE NA AKCEPTACJĘ'),
        ),
      ),
    ));

    expect(find.text('OCZEKUJE NA AKCEPTACJĘ'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/quest_card_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/quests/quest_card.dart
import 'package:flutter/material.dart';

import '../../models/change_request.dart';
import '../../models/quest.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

String _rewardLine(ChangeSet reward) {
  final parts = <String>[
    if (reward.currentXp != null) '+${reward.currentXp} XP',
    for (final t in reward.traits) '${t.name} ${t.value}',
  ];
  return parts.join(' · ');
}

/// The ornamental card shared by the Tablica/Moje/Dziennik tabs. It only
/// renders the frame, title, reward pills, and whatever the caller hands it
/// -- each tab decides its own caption line, actions, and status badge, so
/// this file never needs to know about the take/abandon/withdraw/complete
/// verbs or the outcome-colour rules.
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    this.posterOrHolderLine,
    this.actions = const [],
    this.statusBadge,
  });

  final Quest quest;
  final String? posterOrHolderLine;
  final List<Widget> actions;
  final Widget? statusBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: crimson, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: cardShadowColor, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopBand(label: '✦ ${_bandLabel(quest.status)} ✦'),
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
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text(
                        quest.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: fontDisplay,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: inkHeading,
                        ),
                      ),
                      if (posterOrHolderLine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          posterOrHolderLine!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                            color: traitNameInk,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _rewardLine(quest.reward),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: inkHeading),
                      ),
                      if (statusBadge != null) ...[
                        const SizedBox(height: 8),
                        statusBadge!,
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
                const Positioned(top: 0, left: 0, child: CornerOrnament()),
                const Positioned(top: 0, right: 0, child: CornerOrnament(mirrored: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bandLabel(QuestStatus status) => switch (status) {
        QuestStatus.open => 'Na tablicy',
        QuestStatus.assigned => 'W trakcie',
        QuestStatus.pendingReview => 'W trakcie',
        QuestStatus.completed => 'Ukończone',
        QuestStatus.failed => 'Nieudane',
        QuestStatus.cancelled => 'Wycofane',
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/quest_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/quests/quest_card.dart test/features/quest_card_test.dart
git commit -m "feat: add the shared QuestCard widget"
```

---

### Task 14: `QuestsScreen` — tab host and the Tablica (board) tab

**Files:**
- Modify: `lib/features/quests/quests_screen.dart` (replace the Task 12 stub)
- Test: `test/features/quests_screen_test.dart`

**Interfaces:**
- Consumes: `openQuestsProvider`, `myOwnCharacterIdsProvider` (Task 10), `charactersProvider`, `appUserProvider`, `QuestCard` (Task 13), `QuestRepository.take` (Task 5).
- Produces: `class QuestsScreen extends ConsumerStatefulWidget` with a `TabBar` (`Key('quests-tab-board')`, `Key('quests-tab-mine')`, `Key('quests-tab-log')`); `Key('take-quest-<id>')` buttons on each open quest's card. Moje/Dziennik tab bodies are stubbed as `SizedBox.shrink()` in this task — Tasks 15/16 fill them in.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/quests_screen_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/quests_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: QuestsScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
  });
  await db.collection('quests').add({
    'title': 'Posprzątaj garaż',
    'posterUid': 'u2',
    'posterEmail': 'bob@example.com',
    'posterName': 'Bob',
    'status': 'open',
    'reward': {'current_xp': 50},
    'createdAt': FieldValue.serverTimestamp(),
  });
  return db;
}

void main() {
  testWidgets('the Tablica tab lists open quests with a Podejmij action', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    expect(find.text('Posprzątaj garaż'), findsOneWidget);
    expect(find.textContaining('Podejmij'), findsOneWidget);
  });

  testWidgets('tapping Podejmij with exactly one owned character takes it immediately', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.tap(find.textContaining('Podejmij'));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'assigned');
    expect(quest['assignedToCharacterId'], 'c1');
    expect(find.text('Posprzątaj garaż'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/quests_screen_test.dart`
Expected: FAIL — the stub from Task 12 has no tabs/content.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/quests/quests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quest_repository.dart';
import '../../models/character.dart';
import '../../models/quest.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import 'quest_card.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  List<Character> _ownCharacters() {
    final user = ref.read(appUserProvider).value;
    final feed = ref.read(charactersProvider).value;
    if (user == null || feed == null) return const [];
    final email = user.email.toLowerCase();
    return [
      for (final c in feed.characters)
        if (c.email.toLowerCase() == email) c,
    ];
  }

  Future<Character?> _pickCharacter(List<Character> characters) async {
    if (characters.length == 1) return characters.first;
    return showDialog<Character>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: parchment,
        title: const Text('Wybierz postać'),
        children: [
          for (final c in characters)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(c),
              child: Text(c.name),
            ),
        ],
      ),
    );
  }

  Future<void> _take(Quest quest) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final characters = _ownCharacters();
    if (characters.isEmpty) return;
    final character = await _pickCharacter(characters);
    if (character == null) return;
    try {
      await ref.read(questRepositoryProvider).take(
            quest,
            characterId: character.id,
            characterName: character.name,
            email: user.email,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: parchmentMuted),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          'Zadania',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: parchmentLight,
          unselectedLabelColor: parchmentMuted,
          indicatorColor: gold,
          tabs: const [
            Tab(key: Key('quests-tab-board'), text: 'TABLICA'),
            Tab(key: Key('quests-tab-mine'), text: 'MOJE'),
            Tab(key: Key('quests-tab-log'), text: 'DZIENNIK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BoardTab(onTake: _take),
          const SizedBox.shrink(),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _BoardTab extends ConsumerWidget {
  const _BoardTab({required this.onTake});

  final Future<void> Function(Quest quest) onTake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openQuestsProvider);
    return open.when(
      loading: () => const Center(child: CircularProgressIndicator(color: gold)),
      error: (e, _) => Center(
        child: Text('Nie udało się wczytać zadań: $e',
            style: const TextStyle(color: parchmentMuted)),
      ),
      data: (quests) => quests.isEmpty
          ? const Center(
              child: Text('Brak otwartych zadań',
                  style: TextStyle(color: parchmentMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final quest in quests)
                  QuestCard(
                    key: Key('quest-${quest.id}'),
                    quest: quest,
                    posterOrHolderLine: 'Wystawione przez: ${quest.posterName}',
                    actions: [
                      TextButton(
                        key: Key('take-quest-${quest.id}'),
                        onPressed: () => onTake(quest),
                        child: const Text('Podejmij'),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/quests_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/quests/quests_screen.dart test/features/quests_screen_test.dart
git commit -m "feat: add QuestsScreen with a working Tablica tab"
```

---

### Task 15: Moje tab — assigned-to-me and posted-by-me sections

**Files:**
- Modify: `lib/features/quests/quests_screen.dart`
- Test: `test/features/quests_screen_test.dart` (add cases)

**Interfaces:**
- Consumes: `myAssignedQuestsProvider`, `myPostedQuestsProvider` (Task 10), `QuestRepository.abandon`/`markComplete`/`withdraw` (Tasks 5–6).
- Produces: `Key('complete-quest-<id>')`, `Key('abandon-quest-<id>')`, `Key('withdraw-quest-<id>')`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/quests_screen_test.dart`:

```dart
Future<FakeFirebaseFirestore> _seedMine() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
  });
  await db.collection('quests').add({
    'title': 'Ugotuj obiad',
    'posterUid': 'u2',
    'posterEmail': 'bob@example.com',
    'posterName': 'Bob',
    'assignedToCharacterId': 'c1',
    'assignedToCharacterName': 'Grommash',
    'assignedToEmail': 'ala@example.com',
    'status': 'assigned',
    'reward': {'current_xp': 30},
    'createdAt': FieldValue.serverTimestamp(),
  });
  await db.collection('quests').add({
    'title': 'Zrób pranie',
    'posterUid': 'u1',
    'posterEmail': 'ala@example.com',
    'posterName': 'Ala',
    'status': 'open',
    'reward': {'current_xp': 20},
    'createdAt': FieldValue.serverTimestamp(),
  });
  return db;
}

testWidgets('Moje shows an assigned-to-me quest (Ukończ/Porzuć) and a posted-by-me one (Wycofaj)', (tester) async {
  final db = await _seedMine();
  await _pump(tester, db);

  await tester.tap(find.byKey(const Key('quests-tab-mine')));
  await tester.pumpAndSettle();

  expect(find.text('Ugotuj obiad'), findsOneWidget);
  expect(find.textContaining('Ukończ'), findsOneWidget);
  expect(find.textContaining('Porzuć'), findsOneWidget);
  expect(find.text('Zrób pranie'), findsOneWidget);
  expect(find.textContaining('Wycofaj'), findsOneWidget);
});

testWidgets('tapping Ukończ raises a linked change request and clears the action', (tester) async {
  final db = await _seedMine();
  await _pump(tester, db);
  await tester.tap(find.byKey(const Key('quests-tab-mine')));
  await tester.pumpAndSettle();

  await tester.tap(find.textContaining('Ukończ'));
  await tester.pumpAndSettle();

  final quests = (await db.collection('quests').get()).docs;
  final ugotuj = quests.firstWhere((d) => d.data()['title'] == 'Ugotuj obiad');
  expect(ugotuj.data()['status'], 'pending_review');
  expect((await db.collection('change_requests').get()).docs, hasLength(1));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/quests_screen_test.dart`
Expected: FAIL — the Moje tab is still `SizedBox.shrink()`.

- [ ] **Step 3: Write the implementation**

Replace the two `SizedBox.shrink()` placeholders in `_QuestsScreenState.build`'s `TabBarView` with `_MineTab(...)` and `_LogTab()` (the latter stays a placeholder until Task 16). Add handler methods to `_QuestsScreenState`:

```dart
  Future<void> _abandon(Quest quest) async {
    try {
      await ref.read(questRepositoryProvider).abandon(quest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _complete(Quest quest) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    try {
      await ref.read(questRepositoryProvider).markComplete(
            quest,
            requesterUid: user.uid,
            requesterEmail: user.email,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _withdraw(Quest quest) async {
    try {
      await ref.read(questRepositoryProvider).withdraw(quest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
```

And in the `TabBarView`'s `children`:

```dart
        children: [
          _BoardTab(onTake: _take),
          _MineTab(onAbandon: _abandon, onComplete: _complete, onWithdraw: _withdraw),
          const _LogTab(),
        ],
```

Add the `_MineTab` widget:

```dart
class _MineTab extends ConsumerWidget {
  const _MineTab({
    required this.onAbandon,
    required this.onComplete,
    required this.onWithdraw,
  });

  final Future<void> Function(Quest quest) onAbandon;
  final Future<void> Function(Quest quest) onComplete;
  final Future<void> Function(Quest quest) onWithdraw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(myAssignedQuestsProvider).value ?? const <Quest>[];
    final posted = ref.watch(myPostedQuestsProvider).value ?? const <Quest>[];
    final active = assigned
        .where((q) => q.status == QuestStatus.assigned || q.status == QuestStatus.pendingReview)
        .toList();
    final myOpen = posted.where((q) => q.status == QuestStatus.open).toList();

    if (active.isEmpty && myOpen.isEmpty) {
      return const Center(
        child: Text('Brak własnych zadań', style: TextStyle(color: parchmentMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (active.isNotEmpty) ...[
          const _SectionLabel('✦ PRZYPISANE DO MNIE ✦'),
          for (final quest in active)
            QuestCard(
              key: Key('quest-${quest.id}'),
              quest: quest,
              posterOrHolderLine: 'Wystawione przez: ${quest.posterName}',
              statusBadge: quest.status == QuestStatus.pendingReview
                  ? const Text('OCZEKUJE NA AKCEPTACJĘ',
                      style: TextStyle(fontSize: 10, color: crimson))
                  : null,
              actions: quest.status == QuestStatus.assigned
                  ? [
                      TextButton(
                        key: Key('complete-quest-${quest.id}'),
                        onPressed: () => onComplete(quest),
                        child: const Text('Ukończ'),
                      ),
                      TextButton(
                        key: Key('abandon-quest-${quest.id}'),
                        onPressed: () => onAbandon(quest),
                        child: const Text('Porzuć'),
                      ),
                    ]
                  : const [],
            ),
        ],
        if (myOpen.isNotEmpty) ...[
          const _SectionLabel('✦ WYSTAWIONE PRZEZE MNIE ✦'),
          for (final quest in myOpen)
            QuestCard(
              key: Key('quest-${quest.id}'),
              quest: quest,
              posterOrHolderLine: 'Otwarte — nikt nie podjął',
              actions: [
                TextButton(
                  key: Key('withdraw-quest-${quest.id}'),
                  onPressed: () => onWithdraw(quest),
                  child: const Text('Wycofaj'),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 2,
            color: parchmentMuted,
          ),
        ),
      );
}

class _LogTab extends StatelessWidget {
  const _LogTab();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/quests_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/quests/quests_screen.dart test/features/quests_screen_test.dart
git commit -m "feat: add the Moje tab (assigned-to-me and posted-by-me)"
```

---

### Task 16: Dziennik tab — global outcome log

**Files:**
- Modify: `lib/features/quests/quests_screen.dart`
- Test: `test/features/quests_screen_test.dart` (add cases)

**Interfaces:**
- Consumes: `questLogProvider` (Task 10).
- Produces: replaces the `_LogTab` placeholder from Task 15 with a real one.

- [ ] **Step 1: Write the failing test**

Add to `test/features/quests_screen_test.dart`:

```dart
testWidgets('Dziennik shows completed (green) and failed (red) outcomes', (tester) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('quests').add({
    'title': 'Wynieś śmieci',
    'posterUid': 'u2', 'posterEmail': 'bob@example.com', 'posterName': 'Bob',
    'status': 'completed', 'reward': {'current_xp': 15},
    'createdAt': FieldValue.serverTimestamp(),
  });
  await db.collection('quests').add({
    'title': 'Umyj okna',
    'posterUid': 'u2', 'posterEmail': 'bob@example.com', 'posterName': 'Bob',
    'status': 'failed', 'reward': {'current_xp': 25},
    'createdAt': FieldValue.serverTimestamp(),
  });
  await _pump(tester, db);

  await tester.tap(find.byKey(const Key('quests-tab-log')));
  await tester.pumpAndSettle();

  expect(find.text('Wynieś śmieci'), findsOneWidget);
  expect(find.text('ZAAKCEPTOWANE'), findsOneWidget);
  expect(find.text('Umyj okna'), findsOneWidget);
  expect(find.text('ODRZUCONE'), findsOneWidget);

  final acceptedBadge = tester.widget<Text>(find.text('ZAAKCEPTOWANE'));
  final rejectedBadge = tester.widget<Text>(find.text('ODRZUCONE'));
  expect(acceptedBadge.style!.color, isNot(rejectedBadge.style!.color));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/quests_screen_test.dart`
Expected: FAIL — `_LogTab` renders nothing.

- [ ] **Step 3: Write the implementation**

Replace the `_LogTab` class from Task 15:

```dart
class _LogTab extends ConsumerWidget {
  const _LogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(questLogProvider);
    return log.when(
      loading: () => const Center(child: CircularProgressIndicator(color: gold)),
      error: (e, _) => Center(
        child: Text('Nie udało się wczytać dziennika: $e',
            style: const TextStyle(color: parchmentMuted)),
      ),
      data: (quests) => quests.isEmpty
          ? const Center(
              child: Text('Dziennik jest pusty', style: TextStyle(color: parchmentMuted)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final quest in quests)
                  QuestCard(
                    key: Key('quest-${quest.id}'),
                    quest: quest,
                    posterOrHolderLine:
                        '${quest.posterName} · ${quest.assignedToCharacterName ?? "—"}',
                    statusBadge: _outcomeBadge(quest.status),
                  ),
              ],
            ),
    );
  }

  Widget? _outcomeBadge(QuestStatus status) {
    // The one place this app's palette departs from pure crimson/gold —
    // muted moss-green / muted brick-red so a scan of the log reads status
    // at a glance, per the design spec.
    return switch (status) {
      QuestStatus.completed => const Text(
          'ZAAKCEPTOWANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: Color(0xFF3C6E3C),
          ),
        ),
      QuestStatus.failed => const Text(
          'ODRZUCONE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: Color(0xFF8C3228),
          ),
        ),
      QuestStatus.cancelled => const Text(
          'WYCOFANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: parchmentMuted,
          ),
        ),
      _ => null,
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/quests_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/quests/quests_screen.dart test/features/quests_screen_test.dart
git commit -m "feat: add the Dziennik (log) tab"
```

---

### Task 17: `NewQuestScreen`

**Files:**
- Create: `lib/features/quests/new_quest_screen.dart`
- Test: `test/features/new_quest_screen_test.dart`

**Interfaces:**
- Consumes: `questRosterProvider` (Task 10), `QuestRepository.create` (Task 4), `appUserProvider`.
- Produces: `class NewQuestScreen extends ConsumerStatefulWidget`, `Key('quest-title')`, `Key('quest-description')`, `Key('quest-reward-xp')`, `Key('quest-target-picker')`, `Key('submit-quest')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/new_quest_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/new_quest_screen.dart';

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: NewQuestScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('quest_roster').doc('c1').set({
    'characterName': 'Grommash', 'email': 'ala@example.com',
  });
  return db;
}

void main() {
  testWidgets('leaving the character picker empty posts to the board', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '50');
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'open');
    expect(quest.containsKey('assignedToCharacterId'), isFalse);
  });

  testWidgets('picking a roster character assigns directly', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Ugotuj obiad');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '30');
    await tester.tap(find.byKey(const Key('quest-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grommash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'assigned');
    expect(quest['assignedToCharacterId'], 'c1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/new_quest_screen_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/quests/new_quest_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../models/quest.dart';
import '../../models/quest_roster_entry.dart';
import '../../providers/auth_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

class NewQuestScreen extends ConsumerStatefulWidget {
  const NewQuestScreen({super.key});

  @override
  ConsumerState<NewQuestScreen> createState() => _NewQuestScreenState();
}

class _NewQuestScreenState extends ConsumerState<NewQuestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController();
  QuestRosterEntry? _target;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  Future<void> _pickTarget(List<QuestRosterEntry> roster) async {
    final picked = await showDialog<QuestRosterEntry?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: parchment,
        title: const Text('Wybierz postać'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('— Tablica (dowolna osoba) —'),
          ),
          for (final entry in roster)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry),
              child: Text(entry.characterName),
            ),
        ],
      ),
    );
    setState(() => _target = picked);
  }

  Future<void> _submit(String uid, String email, String name) async {
    final title = _titleController.text.trim();
    final xp = int.tryParse(_xpController.text.trim());
    if (title.isEmpty) return;
    setState(() => _submitting = true);
    final target = _target;
    final quest = Quest(
      id: '',
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      posterUid: uid,
      posterEmail: email,
      posterName: name,
      assignedToCharacterId: target?.characterId,
      assignedToCharacterName: target?.characterName,
      assignedToEmail: target?.email,
      status: target == null ? QuestStatus.open : QuestStatus.assigned,
      reward: ChangeSet(currentXp: xp),
    );
    try {
      await ref.read(questRepositoryProvider).create(quest);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Nie udało się wystawić zadania: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final roster = ref.watch(questRosterProvider).value ?? const <QuestRosterEntry>[];

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: parchmentMuted),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          'Nowy quest',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: crimson, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: const BoxDecoration(gradient: cardGradient),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('quest-title'),
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Tytuł'),
                    ),
                    TextField(
                      key: const Key('quest-description'),
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)'),
                      maxLines: 2,
                    ),
                    TextField(
                      key: const Key('quest-reward-xp'),
                      controller: _xpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Nagroda (XP)'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      key: const Key('quest-target-picker'),
                      onTap: () => _pickTarget(roster),
                      title: Text(
                        _target?.characterName ?? 'Tablica (dowolna osoba)',
                        style: const TextStyle(color: inkHeading),
                      ),
                      trailing: const Icon(Icons.expand_more, color: crimson),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('submit-quest'),
                        onPressed: _submitting || user == null
                            ? null
                            : () => _submit(user.uid, user.email, user.name),
                        child: Text(
                          (_target == null ? 'Wystaw na tablicę' : 'Wystaw zadanie')
                              .toUpperCase(),
                        ),
                      ),
                    ),
                    const BottomBand(),
                  ],
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/new_quest_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Wire up the FAB and commit**

In `lib/features/home/home_screen.dart`'s `_QuestFabState`, change the "Zadania" mini-FAB's destination screen choice: `QuestsScreen` already exposes an app-bar action or FAB of its own is not yet in scope — for now leave "Zadania" opening `QuestsScreen` (Task 12) as-is; `NewQuestScreen` is reached from inside `QuestsScreen`'s Tablica tab. Add a small "+" `IconButton` action to `QuestsScreen`'s `AppBar.actions` that pushes `NewQuestScreen`:

```dart
        actions: [
          IconButton(
            key: const Key('open-new-quest'),
            tooltip: 'Nowy quest',
            icon: const Icon(Icons.add),
            color: parchmentMuted,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewQuestScreen()),
            ),
          ),
        ],
```

Add `import 'new_quest_screen.dart';` to `lib/features/quests/quests_screen.dart`, and a widget test asserting `Key('open-new-quest')` pushes `NewQuestScreen` (add to `test/features/quests_screen_test.dart`, following the same `testWidgets`/tap/`pumpAndSettle` pattern as this task's other tests).

```bash
git add lib/features/quests/new_quest_screen.dart lib/features/quests/quests_screen.dart \
        test/features/new_quest_screen_test.dart test/features/quests_screen_test.dart
git commit -m "feat: add NewQuestScreen and wire it from QuestsScreen"
```

---

### Task 18: Existing change-request screens show the quest link

**Files:**
- Modify: `lib/features/requests/change_requests_screen.dart:315-451` (`_RequestCard`)
- Modify: `lib/features/requests/new_change_request_screen.dart:132-232` (`_showDetails`)
- Test: `test/features/change_requests_screen_test.dart` (add case)
- Test: `test/features/new_change_request_screen_test.dart` (add case)

**Interfaces:**
- Consumes: `ChangeRequest.questId`/`.questTitle` (Task 3).
- No new public interfaces — this is a display-only addition.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/change_requests_screen_test.dart`. Its `seed({bool admin = true})` helper already creates one character (`characterId`, a file-level `late String`) owned by `ala@example.com` and signs in as the admin `a1`/`admin@example.com` via `pumpScreen`; this test adds a second, quest-linked request on top of that fixture:

```dart
testWidgets('a quest-originated request shows the Zadanie line', (tester) async {
  final db = await seed();
  await db.collection('change_requests').add({
    'characterId': characterId,
    'characterName': 'Grommash',
    'requesterUid': 'u1',
    'requesterEmail': 'ala@example.com',
    'status': 'pending',
    'changes': {'current_xp': 50},
    'questId': 'q1',
    'questTitle': 'Posprzątaj garaż',
  });
  await pumpScreen(tester, db);

  expect(find.textContaining('Posprzątaj garaż'), findsOneWidget);
});
```

Add to `test/features/new_change_request_screen_test.dart`. Its `seed({int characters = 1})` signs in as `u1`/`ala@example.com`; add a change request in that same uid's name with `questId`/`questTitle` set, then tap the own-request row (`Key('my-request-<id>')`, per `new_change_request_screen.dart`'s `_showDetails` wiring) to open the detail dialog:

```dart
testWidgets('a quest-originated own request shows the Zadanie line in its detail dialog', (tester) async {
  final db = await seed();
  final request = await db.collection('change_requests').add({
    'characterId': (await db.collection('characters').get()).docs.single.id,
    'characterName': 'Bohater 0',
    'requesterUid': 'u1',
    'requesterEmail': 'ala@example.com',
    'status': 'pending',
    'changes': {'current_xp': 50},
    'questId': 'q1',
    'questTitle': 'Posprzątaj garaż',
  });
  await pumpScreen(tester, db);

  await tester.tap(find.byKey(Key('my-request-${request.id}')));
  await tester.pumpAndSettle();

  expect(find.textContaining('Posprzątaj garaż'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/change_requests_screen_test.dart test/features/new_change_request_screen_test.dart`
Expected: FAIL — no such text is rendered yet.

- [ ] **Step 3: Write the implementation**

In `lib/features/requests/change_requests_screen.dart`'s `_RequestCard.build`, in the `Column` inside the crimson-bordered inner `Container`, add right after the `requesterEmail` `Text` and before the delta lines:

```dart
                  if (request.questTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Zadanie: ${request.questTitle}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: traitNameInk,
                      ),
                    ),
                  ],
```

In `lib/features/requests/new_change_request_screen.dart`'s `_showDetails`, add the same line right after the status `Text` and before `'Poproszono o'`:

```dart
              if (request.questTitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Zadanie: ${request.questTitle}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: traitNameInk,
                  ),
                ),
              ],
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/change_requests_screen_test.dart test/features/new_change_request_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/requests/change_requests_screen.dart lib/features/requests/new_change_request_screen.dart \
        test/features/change_requests_screen_test.dart test/features/new_change_request_screen_test.dart
git commit -m "feat: show the linked quest on change-request screens"
```

---

### Task 19: Admin "Uczestnicy zadań" roster panel

**Files:**
- Modify: `lib/features/users/user_management_screen.dart`
- Test: `test/features/user_management_screen_test.dart` (add cases)

**Interfaces:**
- Consumes: `questRosterProvider` (Task 10), `QuestRosterRepository.add`/`.remove` (Task 8), `charactersProvider`.
- Produces: `Key('quest-roster-toggle-<characterId>')` switches, one per character, in a new section between `_HiddenCharactersSection` and the users list.

- [ ] **Step 1: Write the failing test**

Add to `test/features/user_management_screen_test.dart`. Its `seed()` helper signs in as the admin `u1`/`ala@example.com` (via `pumpScreen`) and seeds one character, "Grommash", owned by `bob@example.com`:

```dart
testWidgets('toggling a character on adds it to quest_roster', (tester) async {
  final db = await seed();
  await pumpScreen(tester, db);

  final characterDoc = (await db.collection('characters').get()).docs.single;
  await tester.tap(find.byKey(Key('quest-roster-toggle-${characterDoc.id}')));
  await tester.pumpAndSettle();

  final rosterDoc = await db.collection('quest_roster').doc(characterDoc.id).get();
  expect(rosterDoc.exists, isTrue);
  expect(rosterDoc.data()!['characterName'], 'Grommash');
});

testWidgets('toggling an already-listed character off removes it', (tester) async {
  final db = await seed();
  final characterDoc = (await db.collection('characters').get()).docs.single;
  await db.collection('quest_roster').doc(characterDoc.id).set({
    'characterName': 'Grommash',
    'email': 'bob@example.com',
  });
  await pumpScreen(tester, db);

  await tester.tap(find.byKey(Key('quest-roster-toggle-${characterDoc.id}')));
  await tester.pumpAndSettle();

  final rosterDoc = await db.collection('quest_roster').doc(characterDoc.id).get();
  expect(rosterDoc.exists, isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/user_management_screen_test.dart`
Expected: FAIL — no such key exists yet.

- [ ] **Step 3: Write the implementation**

In `lib/features/users/user_management_screen.dart`, add imports for `questRosterProvider`/`QuestRosterRepository`/`QuestRosterEntry`. In `_UserManagementScreenState.build`, watch the roster and insert a new section between `_HiddenCharactersSection` and the `Expanded(child: users.when(...))`:

```dart
    final roster = ref.watch(questRosterProvider).value ?? const <QuestRosterEntry>[];
    final rosterIds = {for (final e in roster) e.characterId};
```

```dart
              _HiddenCharactersSection(...), // unchanged
              _QuestRosterSection(
                characters: characters,
                rosterIds: rosterIds,
                onToggle: (character, onRoster) async {
                  final repo = ref.read(questRosterRepositoryProvider);
                  if (onRoster) {
                    await repo.remove(character.id);
                  } else {
                    await repo.add(
                      characterId: character.id,
                      characterName: character.name,
                      email: character.email,
                    );
                  }
                },
              ),
```

Add the new widget, mirroring `_HiddenCharactersSection`'s layout conventions:

```dart
class _QuestRosterSection extends StatelessWidget {
  const _QuestRosterSection({
    required this.characters,
    required this.rosterIds,
    required this.onToggle,
  });

  final List<Character> characters;
  final Set<String> rosterIds;
  final Future<void> Function(Character character, bool currentlyOnRoster) onToggle;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uczestnicy zadań',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 11,
              letterSpacing: 2,
              color: parchmentMuted,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final c in characters)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.name, style: const TextStyle(color: parchmentLight)),
                        Switch(
                          key: Key('quest-roster-toggle-${c.id}'),
                          value: rosterIds.contains(c.id),
                          onChanged: (_) => onToggle(c, rosterIds.contains(c.id)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: crimsonBorderFaint, height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/user_management_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/users/user_management_screen.dart test/features/user_management_screen_test.dart
git commit -m "feat: admin panel to manage the quest roster"
```

---

## Final Verification

- [ ] Run `flutter analyze` — expect zero issues.
- [ ] Run `flutter test` — expect all tests green.
- [ ] Run `cd tools/rules-test && npm test` — expect all tests green.
- [ ] Manually smoke-test on a device/emulator per `.claude/skills/installing-app/SKILL.md`: post an open quest, take it from a second account, mark it complete, accept it as admin and confirm XP landed, and confirm the "Zadanie:" line shows on the admin card.
