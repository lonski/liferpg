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
