import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/models/app_user.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/auth_providers.dart';
import 'package:liferpg/providers/character_providers.dart';
import 'package:liferpg/providers/seen_achievements_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/achievements_test_support.dart';

Future<ProviderContainer> containerFor(
  FakeFirebaseFirestore db, {
  bool resetPrefs = true,
}) async {
  if (resetPrefs) SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'zosia', email: 'zosia@example.com'),
    )),
    sharedPreferencesProvider
        .overrideWithValue(await SharedPreferences.getInstance()),
  ]);
  addTearDown(container.dispose);
  container.listen(seenAchievementsProvider, (_, _) {});
  container.listen(charactersProvider, (_, _) {});
  await container.read(charactersProvider.future);
  await Future<void>.delayed(Duration.zero);
  return container;
}

Future<void> addBadge(FakeFirebaseFirestore db, String id) async {
  final data = await characterData(db);
  await db.collection('characters').doc('c1').update({
    'achievements': [
      ...(data['achievements'] as List? ?? []),
      achievementMap(id: id),
    ],
  });
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('badges that existed before the first run seed as seen', () async {
    final db = await seedWorld(achievements: [achievementMap(id: 'old')]);
    final container = await containerFor(db);
    expect(container.read(seenAchievementsProvider), {'old'});
  });

  test('a badge appearing later is unseen until marked, and that persists',
      () async {
    final db = await seedWorld(achievements: [achievementMap(id: 'old')]);
    final container = await containerFor(db);
    await addBadge(db, 'new');
    expect(container.read(seenAchievementsProvider)!.contains('new'), isFalse);

    container.read(seenAchievementsProvider.notifier).markSeen('new');
    expect(container.read(seenAchievementsProvider), {'old', 'new'});

    final restarted = await containerFor(db, resetPrefs: false);
    expect(restarted.read(seenAchievementsProvider), {'old', 'new'});
  });

  test('a cache-only first snapshot does not seed, and nothing reads as new',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cached = CharacterFeed(
      characters: [
        Character.fromMap('c1', zosiaCharacter(achievements: [achievementMap()]))
      ],
      isFromCache: true,
      hasPendingWrites: false,
    );
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appUserProvider.overrideWith((ref) => Stream.value(const AppUser(
            uid: 'zosia', name: 'Zosia', email: 'zosia@example.com',
            admin: false, readOnlyOthers: false))),
      charactersProvider.overrideWith((ref) => Stream.value(cached)),
    ]);
    addTearDown(container.dispose);
    container.listen(appUserProvider, (_, _) {});
    container.listen(seenAchievementsProvider, (_, _) {});
    await container.read(appUserProvider.future);
    await container.read(charactersProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(seenAchievementsProvider), isNull);
    container.read(seenAchievementsProvider.notifier).markSeen('a1');
    expect(prefs.getStringList('seen_achievements_zosia'), isNull);
  });
}
