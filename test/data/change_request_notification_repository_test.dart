import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notified pending ids are null when nothing was ever saved', () async {
    SharedPreferences.setMockInitialValues({});
    final repo =
        ChangeRequestNotificationRepository(await SharedPreferences.getInstance());

    expect(repo.loadNotifiedPendingIds('u1'), isNull);
  });

  test('notified pending ids round-trip, including an empty save', () async {
    SharedPreferences.setMockInitialValues({});
    final repo =
        ChangeRequestNotificationRepository(await SharedPreferences.getInstance());

    await repo.saveNotifiedPendingIds('u1', {'a', 'b'});
    expect(repo.loadNotifiedPendingIds('u1'), {'a', 'b'});

    await repo.saveNotifiedPendingIds('u1', {});
    expect(repo.loadNotifiedPendingIds('u1'), isNotNull);
    expect(repo.loadNotifiedPendingIds('u1'), isEmpty);
  });

  test('notified pending ids are scoped per uid', () async {
    SharedPreferences.setMockInitialValues({});
    final repo =
        ChangeRequestNotificationRepository(await SharedPreferences.getInstance());

    await repo.saveNotifiedPendingIds('u1', {'a'});
    await repo.saveNotifiedPendingIds('u2', {'b'});

    expect(repo.loadNotifiedPendingIds('u1'), {'a'});
    expect(repo.loadNotifiedPendingIds('u2'), {'b'});
  });

  test('known statuses are null when nothing was ever saved', () async {
    SharedPreferences.setMockInitialValues({});
    final repo =
        ChangeRequestNotificationRepository(await SharedPreferences.getInstance());

    expect(repo.loadKnownStatuses('u1'), isNull);
  });

  test('known statuses round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final repo =
        ChangeRequestNotificationRepository(await SharedPreferences.getInstance());

    await repo.saveKnownStatuses('u1', {'a': 'pending', 'b': 'accepted'});

    expect(repo.loadKnownStatuses('u1'), {'a': 'pending', 'b': 'accepted'});
  });

  test('known statuses are scoped per uid', () async {
    SharedPreferences.setMockInitialValues({});
    final repo =
        ChangeRequestNotificationRepository(await SharedPreferences.getInstance());

    await repo.saveKnownStatuses('u1', {'a': 'pending'});
    await repo.saveKnownStatuses('u2', {'a': 'accepted'});

    expect(repo.loadKnownStatuses('u1'), {'a': 'pending'});
    expect(repo.loadKnownStatuses('u2'), {'a': 'accepted'});
  });
}
