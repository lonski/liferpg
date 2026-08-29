import 'package:cloud_firestore/cloud_firestore.dart';

/// Documents in `change_requests` are written only by this app, but the
/// roster's history with a React-era database argues against trusting the
/// schema, so these coerce in the same style as `Character.fromMap`.
num? _asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

String? _asString(Object? v) => v is String ? v : null;

/// A single trait upsert: the trait with this `name` has its value replaced,
/// or is appended to the character if no trait carries that name. There is no
/// remove operation and no delta on a trait's value — the value is free-form
/// text, so a delta on it would be meaningless.
class TraitChange {
  const TraitChange({required this.name, required this.value});

  final String name;
  final String value;

  factory TraitChange.fromMap(Map<String, dynamic> data) => TraitChange(
        name: _asString(data['name']) ?? '',
        value: _asString(data['value']) ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is TraitChange && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// The numeric entries are **deltas**, not target values: a request stays
/// correct if the character changes between posting and acceptance.
class ChangeSet {
  const ChangeSet({
    this.currentXp,
    this.gold,
    this.traits = const [],
  });

  final num? currentXp;
  final num? gold;
  final List<TraitChange> traits;

  bool get isEmpty =>
      currentXp == null && gold == null && traits.isEmpty;

  factory ChangeSet.fromMap(Map<String, dynamic> data) {
    final rawTraits = data['traits'];
    return ChangeSet(
      currentXp: _asNum(data['current_xp']),
      gold: _asNum(data['gold']),
      traits: rawTraits is List
          ? rawTraits
              .whereType<Map>()
              .map((t) => TraitChange.fromMap(Map<String, dynamic>.from(t)))
              .toList()
          : const <TraitChange>[],
    );
  }

  Map<String, dynamic> toMap() => {
        if (currentXp != null) 'current_xp': currentXp,
        if (gold != null) 'gold': gold,
        if (traits.isNotEmpty)
          'traits': traits.map((t) => t.toMap()).toList(),
      };
}

enum ChangeRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  String get wire => name;

  /// Anything unrecognised is treated as pending: a request nobody can act on
  /// is worse than one that shows up in the queue again.
  static ChangeRequestStatus parse(Object? v) {
    for (final s in ChangeRequestStatus.values) {
      if (s.name == v) return s;
    }
    return ChangeRequestStatus.pending;
  }
}

class ChangeRequest {
  const ChangeRequest({
    required this.id,
    required this.characterId,
    required this.characterName,
    required this.requesterUid,
    required this.requesterEmail,
    required this.status,
    required this.changes,
    this.reason,
    this.createdAt,
    this.appliedChanges,
    this.decidedBy,
    this.decidedAt,
    this.rejectionReason,
    this.questId,
    this.questTitle,
  });

  final String id;
  final String characterId;
  final String characterName;
  final String requesterUid;
  final String requesterEmail;
  final ChangeRequestStatus status;

  /// What was asked for. Preserved verbatim even when an admin edits the
  /// request before accepting — the edit lands in [appliedChanges].
  final ChangeSet changes;
  final String? reason;

  /// Null while the server timestamp is still pending on a local write.
  final DateTime? createdAt;

  /// What the admin actually applied. Null until accepted.
  final ChangeSet? appliedChanges;
  final String? decidedBy;
  final DateTime? decidedAt;

  /// Set only on a reject decision. Cleared by [restoreToPending] along with
  /// [decidedBy]/[decidedAt], since it belongs to the decision being undone.
  final String? rejectionReason;

  /// Set only when this request was raised by completing a quest.
  final String? questId;

  /// Denormalised quest title, so the admin card and the requester's own
  /// history can show the link without an extra read.
  final String? questTitle;

  bool get isPending => status == ChangeRequestStatus.pending;

  static DateTime? _asDate(Object? v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static ChangeSet? _asChangeSet(Object? v) =>
      v is Map ? ChangeSet.fromMap(Map<String, dynamic>.from(v)) : null;

  factory ChangeRequest.fromMap(String id, Map<String, dynamic> data) =>
      ChangeRequest(
        id: id,
        characterId: _asString(data['characterId']) ?? '',
        characterName: _asString(data['characterName']) ?? '',
        requesterUid: _asString(data['requesterUid']) ?? '',
        requesterEmail: _asString(data['requesterEmail']) ?? '',
        status: ChangeRequestStatus.parse(data['status']),
        changes: _asChangeSet(data['changes']) ?? const ChangeSet(),
        reason: _asString(data['reason']),
        createdAt: _asDate(data['createdAt']),
        appliedChanges: _asChangeSet(data['appliedChanges']),
        decidedBy: _asString(data['decidedBy']),
        decidedAt: _asDate(data['decidedAt']),
        rejectionReason: _asString(data['rejectionReason']),
        questId: _asString(data['questId']),
        questTitle: _asString(data['questTitle']),
      );

  /// `createdAt` is deliberately absent: the repository writes it as a server
  /// timestamp rather than trusting the device clock.
  Map<String, dynamic> toMap() => {
        'characterId': characterId,
        'characterName': characterName,
        'requesterUid': requesterUid,
        'requesterEmail': requesterEmail,
        'status': status.wire,
        'changes': changes.toMap(),
        if (reason != null) 'reason': reason,
        if (appliedChanges != null) 'appliedChanges': appliedChanges!.toMap(),
        if (decidedBy != null) 'decidedBy': decidedBy,
        if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (questId != null) 'questId': questId,
        if (questTitle != null) 'questTitle': questTitle,
      };
}
