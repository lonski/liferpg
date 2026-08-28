import 'package:shared_preferences/shared_preferences.dart';

/// An admin's own on-device list of characters they've hidden from their
/// roster view. Deliberately local-only, never written to Firestore: hiding
/// a card is this admin's personal declutter, not a change to the character
/// itself, so it must never affect what the owning player, other admins, or
/// this same admin on a different device see.
class HiddenCharactersRepository {
  HiddenCharactersRepository(this._prefs);

  final SharedPreferences _prefs;

  String _key(String uid) => 'hidden_characters_$uid';

  Set<String> load(String uid) =>
      _prefs.getStringList(_key(uid))?.toSet() ?? const <String>{};

  Future<void> save(String uid, Set<String> characterIds) =>
      _prefs.setStringList(_key(uid), characterIds.toList());
}
