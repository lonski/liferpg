import '../models/change_request.dart';

/// Which of the admin queue's pending requests are newly pending since the
/// last check, and the notified-id set to persist afterwards.
///
/// [previouslyNotified] is `null` on the very first check for a uid (nothing
/// saved yet): that snapshot seeds the baseline silently instead of flooding
/// notifications for every request that already existed before this feature
/// shipped. A request that leaves the pending list (decided, cancelled) is
/// dropped from the returned set, so if it's later restored to pending it
/// notifies again rather than being remembered forever.
class PendingRequestDiff {
  const PendingRequestDiff({required this.toNotify, required this.notifiedIds});

  final List<ChangeRequest> toNotify;
  final Set<String> notifiedIds;
}

PendingRequestDiff diffPendingRequests({
  required List<ChangeRequest> pending,
  required Set<String>? previouslyNotified,
}) {
  final currentIds = pending.map((r) => r.id).toSet();
  if (previouslyNotified == null) {
    return PendingRequestDiff(toNotify: const [], notifiedIds: currentIds);
  }
  final toNotify =
      pending.where((r) => !previouslyNotified.contains(r.id)).toList();
  return PendingRequestDiff(toNotify: toNotify, notifiedIds: currentIds);
}

/// Which of the signed-in user's own requests just moved from pending to a
/// decision (accepted/rejected) since the last check, and the id->status map
/// to persist afterwards.
///
/// [previouslyKnown] is `null` on the very first check for a uid, seeding the
/// baseline silently for the same reason as [diffPendingRequests]. A request
/// only notifies if it was last seen pending -- one decided before this
/// device ever observed it pending (or cancelled/restored) does not.
class OwnRequestDiff {
  const OwnRequestDiff({required this.toNotify, required this.statuses});

  final List<ChangeRequest> toNotify;
  final Map<String, String> statuses;
}

OwnRequestDiff diffOwnRequests({
  required List<ChangeRequest> requests,
  required Map<String, String>? previouslyKnown,
}) {
  final currentStatuses = {for (final r in requests) r.id: r.status.wire};
  if (previouslyKnown == null) {
    return OwnRequestDiff(toNotify: const [], statuses: currentStatuses);
  }
  final toNotify = requests.where((r) {
    final wasPending =
        previouslyKnown[r.id] == ChangeRequestStatus.pending.wire;
    final nowDecided = r.status == ChangeRequestStatus.accepted ||
        r.status == ChangeRequestStatus.rejected;
    return wasPending && nowDecided;
  }).toList();
  return OwnRequestDiff(toNotify: toNotify, statuses: currentStatuses);
}
