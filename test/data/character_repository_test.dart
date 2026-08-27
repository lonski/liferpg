import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/models/app_user.dart';

const _admin = AppUser(
  uid: 'u1',
  name: 'Ala',
  email: 'ala@example.com',
  admin: true,
  readOnlyOthers: false,
);

void main() {
  test(
      'a hopelessly malformed document is skipped rather than blanking the roster',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('characters').add({
      'name': 'Ala',
      'email': 'ala@example.com',
      'level': 2,
      'current_xp': 10,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
    // A trait entry that is a Map but has non-String keys survives the
    // "is Map" check yet still throws inside Map<String, dynamic>.from --
    // exactly the kind of residual failure the repository must tolerate.
    await db.collection('characters').add({
      'name': 'Corrupt',
      'email': 'corrupt@example.com',
      'level': 2,
      'current_xp': 10,
      'next_level_xp': 100,
      'favour': 0,
      'traits': [
        {1: 'a', 2: 'b'},
      ],
    });
    await db.collection('characters').add({
      'name': 'Bob',
      'email': 'bob@example.com',
      'level': 5,
      'current_xp': 0,
      'next_level_xp': 200,
      'favour': 1,
      'traits': <dynamic>[],
    });

    final feed = await CharacterRepository(db).watchCharacters(_admin).first;

    expect(feed.characters.map((c) => c.name).toSet(), {'Ala', 'Bob'});
  });
}
