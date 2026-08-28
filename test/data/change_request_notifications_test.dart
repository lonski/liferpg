import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notifications.dart';
import 'package:liferpg/models/change_request.dart';

ChangeRequest _request(String id, ChangeRequestStatus status) => ChangeRequest(
      id: id,
      characterId: 'c1',
      characterName: 'Grommash',
      requesterUid: 'u1',
      requesterEmail: 'ala@example.com',
      status: status,
      changes: const ChangeSet(currentXp: 10),
    );

void main() {
  group('diffPendingRequests', () {
    test('first snapshot seeds the baseline without notifying', () {
      final result = diffPendingRequests(
        pending: [
          _request('a', ChangeRequestStatus.pending),
          _request('b', ChangeRequestStatus.pending),
        ],
        previouslyNotified: null,
      );

      expect(result.toNotify, isEmpty);
      expect(result.notifiedIds, {'a', 'b'});
    });

    test('a pending request not in the notified set is queued', () {
      final result = diffPendingRequests(
        pending: [
          _request('a', ChangeRequestStatus.pending),
          _request('b', ChangeRequestStatus.pending),
        ],
        previouslyNotified: {'a'},
      );

      expect(result.toNotify.map((r) => r.id), ['b']);
      expect(result.notifiedIds, {'a', 'b'});
    });

    test('a request that left the pending list is dropped from the notified set', () {
      final result = diffPendingRequests(
        pending: [_request('a', ChangeRequestStatus.pending)],
        previouslyNotified: {'a', 'b'},
      );

      expect(result.toNotify, isEmpty);
      expect(result.notifiedIds, {'a'});
    });

    test('no new pending requests produces nothing to notify', () {
      final result = diffPendingRequests(
        pending: [_request('a', ChangeRequestStatus.pending)],
        previouslyNotified: {'a'},
      );

      expect(result.toNotify, isEmpty);
      expect(result.notifiedIds, {'a'});
    });
  });

  group('diffOwnRequests', () {
    test('first snapshot seeds the baseline without notifying', () {
      final result = diffOwnRequests(
        requests: [
          _request('a', ChangeRequestStatus.pending),
          _request('b', ChangeRequestStatus.accepted),
        ],
        previouslyKnown: null,
      );

      expect(result.toNotify, isEmpty);
      expect(result.statuses, {'a': 'pending', 'b': 'accepted'});
    });

    test('pending to accepted is queued for notification', () {
      final result = diffOwnRequests(
        requests: [_request('a', ChangeRequestStatus.accepted)],
        previouslyKnown: {'a': 'pending'},
      );

      expect(result.toNotify.map((r) => r.id), ['a']);
      expect(result.statuses, {'a': 'accepted'});
    });

    test('pending to rejected is queued for notification', () {
      final result = diffOwnRequests(
        requests: [_request('a', ChangeRequestStatus.rejected)],
        previouslyKnown: {'a': 'pending'},
      );

      expect(result.toNotify.map((r) => r.id), ['a']);
    });

    test('a request that stays pending does not notify', () {
      final result = diffOwnRequests(
        requests: [_request('a', ChangeRequestStatus.pending)],
        previouslyKnown: {'a': 'pending'},
      );

      expect(result.toNotify, isEmpty);
    });

    test('a request decided before it was ever seen pending does not notify', () {
      final result = diffOwnRequests(
        requests: [_request('a', ChangeRequestStatus.accepted)],
        previouslyKnown: const {},
      );

      expect(result.toNotify, isEmpty);
      expect(result.statuses, {'a': 'accepted'});
    });

    test('a cancelled request does not notify', () {
      final result = diffOwnRequests(
        requests: [_request('a', ChangeRequestStatus.cancelled)],
        previouslyKnown: {'a': 'pending'},
      );

      expect(result.toNotify, isEmpty);
    });
  });
}
