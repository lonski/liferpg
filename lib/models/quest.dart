import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_request.dart';

String? _asString(Object? v) => v is String ? v : null;

/// The device-local calendar day, `yyyy-MM-dd` -- what a daily quest's
/// `lastCompletedDate` is stamped with and compared against. There are no
/// Cloud Functions in this project (see CLAUDE.md), so a daily quest's
/// reset rides the device clock the same way every other client-authoritative
/// write in this app already does.
String dailyQuestStamp([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

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
    this.isDaily = false,
    this.lastCompletedDate,
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

  /// A recurring, admin-assigned chore: always created directly `assigned`
  /// (never posted `open`), and its completion cycles the quest back to
  /// `assigned` instead of a terminal state -- see [lastCompletedDate] and
  /// CLAUDE.md's Daily Quests section for why this never spawns a new
  /// document per day.
  final bool isDaily;

  /// `yyyy-MM-dd`, set when the holder reports completion for the day
  /// (`QuestRepository.markComplete`). Only meaningful when [isDaily] is
  /// true. Compare against [dailyQuestStamp] to know whether today's
  /// instance is still due.
  final String? lastCompletedDate;

  /// Whether this daily quest still needs to be done today. Always false for
  /// a non-daily quest -- callers gate the "Ukończ" action on this rather
  /// than on [status] alone, since `assigned` alone doesn't say whether
  /// today's instance was already reported.
  bool get isDueToday => isDaily && lastCompletedDate != dailyQuestStamp();

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
        isDaily: data['isDaily'] == true,
        lastCompletedDate: _asString(data['lastCompletedDate']),
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
        if (isDaily) 'isDaily': true,
        if (lastCompletedDate != null) 'lastCompletedDate': lastCompletedDate,
      };
}
