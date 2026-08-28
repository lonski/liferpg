/// Shared display formatting for `ChangeRequest`/`ChangeSet` values, used by
/// both the admin queue (`change_requests_screen.dart`) and a requester's own
/// history (`new_change_request_screen.dart`) so the two never drift apart.
library;

import '../../models/change_request.dart';

String signedDelta(num v) => v > 0 ? '+$v' : '$v';

/// Plain interpolation and zero-padding, deliberately — no `intl` dependency.
String formatTimestamp(DateTime t) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${pad(t.month)}-${pad(t.day)} ${pad(t.hour)}:${pad(t.minute)}';
}

String changeRequestStatusLabel(ChangeRequestStatus status) => switch (status) {
      ChangeRequestStatus.pending => 'Oczekuje',
      ChangeRequestStatus.accepted => 'Zaakceptowana',
      ChangeRequestStatus.rejected => 'Odrzucona',
      ChangeRequestStatus.cancelled => 'Anulowana',
    };

/// One line per touched field, e.g. `XP: +50`, `Złoto: -10`, plus one line
/// per trait upsert. Used for both what was asked for (`changes`) and, once
/// decided, what was actually applied (`appliedChanges`).
List<String> changeSetLines(ChangeSet changes) => [
      if (changes.currentXp != null) 'XP: ${signedDelta(changes.currentXp!)}',
      if (changes.gold != null) 'Złoto: ${signedDelta(changes.gold!)}',
      for (final trait in changes.traits) '${trait.name}: ${trait.value}',
    ];
