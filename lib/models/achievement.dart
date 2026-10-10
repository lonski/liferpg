import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_request.dart' show ChangeSet, TraitChange;
import 'electronics_days.dart' show dayOf, formatDay, parseDay;

// Badges are written only by this app, but they live on character documents
// whose history argues against trusting the schema -- coerce in the style of
// Character.fromMap rather than throwing.
num? _asNum(Object? v) {
  final n = v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
  return n != null && n.isFinite ? n : null;
}

String? _asText(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

String _negate(String value) {
  final n = -(num.tryParse(value.trim()) ?? 0);
  return n % 1 == 0 ? n.toInt().toString() : '$n';
}

enum AchievementEmblem {
  place,
  trophy,
  note,
  peak,
  book,
  star;

  String get wire => name;

  static AchievementEmblem parse(Object? v) {
    for (final e in values) {
      if (e.name == v) return e;
    }
    return star;
  }
}

enum AchievementTier {
  gold,
  silver,
  bronze,
  ruby;

  String get wire => name;

  static AchievementTier parse(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return gold;
  }

  /// The metal the award form suggests for a podium place.
  static AchievementTier forPlace(int place) => switch (place) {
    1 => gold,
    2 => silver,
    _ => bronze,
  };
}

/// What a badge paid out. XP / gold / trait are deltas with change-request
/// semantics; [electronicsDays] shifts the banked electronics count. Its own
/// class rather than a ChangeSet field: an `electronics_days` key on
/// ChangeSet could ride along in an ordinary change request, which the
/// create rule does not forbid.
class AchievementReward {
  const AchievementReward({
    this.currentXp,
    this.gold,
    this.trait,
    this.electronicsDays,
  });

  final int? currentXp;
  final num? gold;

  /// At most one, matching the single-trait request form.
  final TraitChange? trait;
  final int? electronicsDays;

  bool get isEmpty =>
      currentXp == null &&
      gold == null &&
      trait == null &&
      electronicsDays == null;

  factory AchievementReward.fromMap(Object? raw) {
    if (raw is! Map) return const AchievementReward();
    TraitChange? trait;
    final rawTraits = raw['traits'];
    if (rawTraits is List) {
      for (final t in rawTraits.whereType<Map>()) {
        final parsed = TraitChange.fromMap(Map<String, dynamic>.from(t));
        if (parsed.name.trim().isNotEmpty &&
            num.tryParse(parsed.value.trim()) != null) {
          trait = parsed;
          break;
        }
      }
    }
    return AchievementReward(
      currentXp: _asNum(raw['current_xp'])?.toInt(),
      gold: _asNum(raw['gold']),
      trait: trait,
      electronicsDays: _asNum(raw['electronics_days'])?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (currentXp != null) 'current_xp': currentXp,
    if (gold != null) 'gold': gold,
    if (trait != null) 'traits': [trait!.toMap()],
    if (electronicsDays != null) 'electronics_days': electronicsDays,
  };

  /// The same reward pointing the other way -- what revoking takes back.
  AchievementReward negated() => AchievementReward(
    currentXp: currentXp == null ? null : -currentXp!,
    gold: gold == null ? null : -gold!,
    trait: trait == null
        ? null
        : TraitChange(name: trait!.name, value: _negate(trait!.value)),
    electronicsDays: electronicsDays == null ? null : -electronicsDays!,
  );

  /// The XP / gold / trait part, for applyCharacterDeltas.
  ChangeSet toChangeSet() => ChangeSet(
    currentXp: currentXp,
    gold: gold,
    traits: trait == null ? const [] : [trait!],
  );
}

/// Everything about a badge an admin may change after awarding it: its
/// presentation, never its reward or award stamp.
class AchievementDetails {
  const AchievementDetails({
    required this.title,
    this.event,
    this.reason,
    required this.date,
    required this.emblem,
    this.place,
    required this.tier,
  });

  final String title;
  final String? event;
  final String? reason;

  /// Local calendar day, as `dayOf` counts it.
  final int date;
  final AchievementEmblem emblem;
  final int? place;
  final AchievementTier tier;
}

/// One entry of `characters/{id}.achievements`.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    this.event,
    this.reason,
    required this.date,
    required this.emblem,
    this.place,
    required this.tier,
    this.reward = const AchievementReward(),
    required this.awardedBy,
    required this.awardedByName,
    required this.awardedAt,
  });

  factory Achievement.fromDetails({
    required String id,
    required AchievementDetails details,
    required AchievementReward reward,
    required String awardedBy,
    required String awardedByName,
    required DateTime awardedAt,
  }) => Achievement(
    id: id,
    title: details.title,
    event: details.event,
    reason: details.reason,
    date: details.date,
    emblem: details.emblem,
    place: details.place,
    tier: details.tier,
    reward: reward,
    awardedBy: awardedBy,
    awardedByName: awardedByName,
    awardedAt: awardedAt,
  );

  final String id;
  final String title;
  final String? event;
  final String? reason;
  final int date;
  final AchievementEmblem emblem;

  /// 1-3; only meaningful with [AchievementEmblem.place].
  final int? place;
  final AchievementTier tier;
  final AchievementReward reward;
  final String awardedBy;
  final String awardedByName;

  /// A client timestamp: Firestore rejects serverTimestamp() inside arrays.
  final DateTime awardedAt;

  /// What the medal draws: a place emblem without a place is a trophy.
  AchievementEmblem get shownEmblem =>
      emblem == AchievementEmblem.place && place == null
      ? AchievementEmblem.trophy
      : emblem;

  /// Drives the card's NOWA chip -- a plain age check, no seen-state.
  bool isNewAt(DateTime now) =>
      now.difference(awardedAt) < const Duration(days: 7);

  static Achievement? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = _asText(raw['id']);
    final title = _asText(raw['title']);
    if (id == null || title == null) return null;
    final rawAwardedAt = raw['awardedAt'];
    final awardedAt = rawAwardedAt is Timestamp
        ? rawAwardedAt.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    final place = _asNum(raw['place'])?.toInt();
    return Achievement(
      id: id,
      title: title,
      event: _asText(raw['event']),
      reason: _asText(raw['reason']),
      date: parseDay(raw['date']) ?? dayOf(awardedAt),
      emblem: AchievementEmblem.parse(raw['emblem']),
      place: place != null && place >= 1 && place <= 3 ? place : null,
      tier: AchievementTier.parse(raw['tier']),
      reward: AchievementReward.fromMap(raw['reward']),
      awardedBy: raw['awardedBy'] is String ? raw['awardedBy'] as String : '',
      awardedByName: raw['awardedByName'] is String
          ? raw['awardedByName'] as String
          : '',
      awardedAt: awardedAt,
    );
  }

  Achievement withDetails(AchievementDetails details) =>
      Achievement.fromDetails(
        id: id,
        details: details,
        reward: reward,
        awardedBy: awardedBy,
        awardedByName: awardedByName,
        awardedAt: awardedAt,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    if (event != null) 'event': event,
    if (reason != null) 'reason': reason,
    'date': formatDay(date),
    'emblem': emblem.wire,
    if (place != null) 'place': place,
    'tier': tier.wire,
    'reward': reward.toMap(),
    'awardedBy': awardedBy,
    'awardedByName': awardedByName,
    'awardedAt': Timestamp.fromDate(awardedAt),
  };

  static int newestFirst(Achievement a, Achievement b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.awardedAt.compareTo(a.awardedAt);
  }
}
