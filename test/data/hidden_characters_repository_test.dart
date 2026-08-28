import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/hidden_characters_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('load returns an empty set when nothing was ever saved', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = HiddenCharactersRepository(await SharedPreferences.getInstance());

    expect(repo.load('u1'), isEmpty);
  });

  test('save then load round-trips the hidden ids', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = HiddenCharactersRepository(await SharedPreferences.getInstance());

    await repo.save('u1', {'c1', 'c2'});

    expect(repo.load('u1'), {'c1', 'c2'});
  });

  test('hidden ids are scoped per uid', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = HiddenCharactersRepository(await SharedPreferences.getInstance());

    await repo.save('u1', {'c1'});
    await repo.save('u2', {'c2'});

    expect(repo.load('u1'), {'c1'});
    expect(repo.load('u2'), {'c2'});
  });
}
