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

  testWidgets('a tap after midnight but before the ticker opens no dialog',
      (tester) async {
    final db = await seed(uid: 'u1', email: _owner);
    var now = DateTime(2026, 10, 22, 23, 59, 50);
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: () => now);

    now = DateTime(2026, 10, 23, 0, 0, 20);
    await tester.tap(find.byKey(const Key('electronics-claim')));
    await tester.pumpAndSettle();

    expect(find.text('DZIEŃ Z ELEKTRONIKĄ?'), findsNothing);
    expect((await db.collection('change_requests').get()).docs, isEmpty);
    // The card refreshed onto the new day (3 banked + 1 accrued).
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a dialog left open across midnight writes nothing',
      (tester) async {
    final db = await seed(uid: 'u1', email: _owner);
    var now = DateTime(2026, 10, 22, 23, 59, 50);
    await pumpPanel(tester, db, uid: 'u1', email: _owner, clock: () => now);

    await tester.tap(find.byKey(const Key('electronics-claim')));
    await tester.pumpAndSettle();
    expect(find.text('DZIEŃ Z ELEKTRONIKĄ?'), findsOneWidget);

    now = DateTime(2026, 10, 23, 0, 0, 20);
    await tester.tap(find.byKey(const Key('electronics-claim-confirm')));
    await tester.pumpAndSettle();

    expect((await db.collection('change_requests').get()).docs, isEmpty);
  });

  testWidgets('an admin dialog left open across midnight writes nothing',
      (tester) async {
    final db = await seed(uid: 'a1', email: 'admin@example.com', admin: true);
    var now = DateTime(2026, 10, 22, 23, 59, 50);
    await pumpPanel(tester, db,
        uid: 'a1', email: 'admin@example.com', clock: () => now);

    await tester.tap(find.byKey(const Key('electronics-claim')));
    await tester.pumpAndSettle();
    now = DateTime(2026, 10, 23, 0, 0, 20);
    await tester.tap(find.byKey(const Key('electronics-claim-confirm')));
    await tester.pumpAndSettle();

    final e = (await db.collection('characters').doc('c1').get())
        .data()!['electronics'] as Map;
    expect(e['claimed'], isEmpty);
    expect(e['days'], 3);
  });

  testWidgets('a readOnlyOthers user can claim on their own character',
      (tester) async {
    final db = await seed(uid: 'r1', email: _owner, readOnlyOthers: true);
    await pumpPanel(tester, db, uid: 'r1', email: _owner, clock: noon);

    await tester.tap(find.byKey(const Key('electronics-claim')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('electronics-claim-confirm')));
    await tester.pumpAndSettle();

    final reqs = await db.collection('change_requests').get();
    expect(reqs.docs, hasLength(1));
    expect(reqs.docs.single.data()['changes'], {'electronics_claim': '2026-10-22'});
    expect(reqs.docs.single.data()['requesterUid'], 'r1');
  });
}
