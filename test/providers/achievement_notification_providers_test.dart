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

/// Delays every roster query, like a real network round-trip after sign-in.
class _SlowCharacterRepository extends CharacterRepository {
  _SlowCharacterRepository(super.db);

  @override
  Stream<CharacterFeed> watchCharacters(AppUser user) async* {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield* super.watchCharacters(user);
  }
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

  test('signing out and back in does not re-announce existing badges', () async {
    final db = await seedWorld(achievements: [achievementMap(id: 'old')]);
    SharedPreferences.setMockInitialValues({});
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'zosia', email: 'zosia@example.com'),
    );
    final service = FakeNotificationService();
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(auth),
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
      changeRequestNotificationServiceProvider.overrideWithValue(service),
      characterRepositoryProvider
          .overrideWithValue(_SlowCharacterRepository(db)),
    ]);
    addTearDown(container.dispose);
    container.listen(achievementNotificationsProvider, (_, _) {});
    container.listen(celebrationQueueProvider, (_, _) {});
    Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 200));
    await wait();
    final repo = container.read(achievementNotificationRepositoryProvider);
    expect(repo.loadCelebratedIds('zosia'), {'old'});

    await auth.signOut();
    await wait();
    await auth.signInWithEmailAndPassword(
        email: 'zosia@example.com', password: 'x');
    await wait();

    expect(repo.loadCelebratedIds('zosia'), {'old'});
    expect(container.read(celebrationQueueProvider), isEmpty);
    expect(service.shown, isEmpty);
  });
}
