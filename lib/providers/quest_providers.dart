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
