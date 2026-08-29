import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_request.dart';

String? _asString(Object? v) => v is String ? v : null;

enum QuestStatus {
  open,
  assigned,
  pendingReview,
  completed,
  failed,
  cancelled;

  String get wire => this == QuestStatus.pendingReview ? 'pending_review' : name;

  /// Anything unrecognised is treated as still-open: a quest nobody can act
  /// on is worse than one that shows up on the board again.
  static QuestStatus parse(Object? v) {
    for (final s in QuestStatus.values) {
      if (s.wire == v) return s;
    }
    return QuestStatus.open;
  }
}

class Quest {
  const Quest({
    required this.id,
    required this.title,
    this.description,
    required this.posterUid,
    required this.posterEmail,
    required this.posterName,
    this.assignedToCharacterId,
    this.assignedToCharacterName,
    this.assignedToEmail,
    required this.status,
    required this.reward,
    this.changeRequestId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String posterUid;
  final String posterEmail;
  final String posterName;
  final String? assignedToCharacterId;
  final String? assignedToCharacterName;
  final String? assignedToEmail;
  final QuestStatus status;

  /// XP delta and/or trait upserts — the exact same shape and semantics as
  /// a `ChangeRequest.changes`, just never carrying a `gold` delta.
  final ChangeSet reward;

  final String? changeRequestId;
  final DateTime? createdAt;

  static DateTime? _asDate(Object? v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  factory Quest.fromMap(String id, Map<String, dynamic> data) => Quest(
        id: id,
        title: _asString(data['title']) ?? '',
        description: _asString(data['description']),
        posterUid: _asString(data['posterUid']) ?? '',
        posterEmail: _asString(data['posterEmail']) ?? '',
        posterName: _asString(data['posterName']) ?? '',
        assignedToCharacterId: _asString(data['assignedToCharacterId']),
        assignedToCharacterName: _asString(data['assignedToCharacterName']),
        assignedToEmail: _asString(data['assignedToEmail']),
        status: QuestStatus.parse(data['status']),
        reward: data['reward'] is Map
            ? ChangeSet.fromMap(Map<String, dynamic>.from(data['reward'] as Map))
            : const ChangeSet(),
        changeRequestId: _asString(data['changeRequestId']),
        createdAt: _asDate(data['createdAt']),
      );

  /// `createdAt` is deliberately absent: the repository writes it as a
  /// server timestamp rather than trusting the device clock.
  Map<String, dynamic> toMap() => {
        'title': title,
        'posterUid': posterUid,
        'posterEmail': posterEmail,
        'posterName': posterName,
        if (description != null) 'description': description,
        if (assignedToCharacterId != null)
          'assignedToCharacterId': assignedToCharacterId,
        if (assignedToCharacterName != null)
          'assignedToCharacterName': assignedToCharacterName,
        if (assignedToEmail != null) 'assignedToEmail': assignedToEmail,
        'status': status.wire,
        'reward': reward.toMap(),
        if (changeRequestId != null) 'changeRequestId': changeRequestId,
      };
}
