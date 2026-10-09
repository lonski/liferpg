import 'dart:math' as math;

/// Electronics days are counted in whole local calendar days. A "day" here is
/// a plain int -- days since 1970-01-01 -- built from the *local* date via
/// `DateTime.utc`, so a DST change can never produce a 23- or 25-hour day and
/// the value stays `const`-friendly. Strings ('YYYY-MM-DD') only exist at the
/// Firestore boundary.
int dayOf(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// 2026-10-10, the first full day after the feature shipped. A character with
/// no `electronics` map counts from 0 here.
const int kElectronicsDaysEpoch = 20736;

final RegExp _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

String formatDay(int day) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(d.year, 4)}-${pad(d.month, 2)}-${pad(d.day, 2)}';
}

int? parseDay(Object? v) {
  if (v is! String) return null;
  final m = _dayPattern.firstMatch(v.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final dd = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, dd);
  // DateTime normalises 2026-02-30 to March; reject instead of guessing.
  if (date.year != y || date.month != mo || date.day != dd) return null;
  return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// How much of the local calendar day containing [now] has elapsed, 0.0-1.0.
double dayFraction(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day + 1);
  final f = now.difference(start).inSeconds / end.difference(start).inSeconds;
  return f.clamp(0.0, 1.0).toDouble();
}

/// The four card states, in the order the spec checks them: claimed, pending,
/// empty, charging.
enum ElectronicsCardState { charging, pending, claimed, empty }

/// The `electronics` map on a character: a banked count as of the start of
/// [asOf], plus recently claimed days. Accrual is lazy -- nothing ticks at
/// midnight; readers add the full days since [asOf], and every write
/// [settle]s that accrual into [days] first.
class ElectronicsDays {
  const ElectronicsDays({
    this.days = 0,
    this.asOf = kElectronicsDaysEpoch,
    this.claimed = const [],
  });

  static const int maxClaimed = 31;

  final int days;
  final int asOf;

  /// Sorted ascending, deduplicated, at most [maxClaimed] entries.
  final List<int> claimed;

  /// Tolerant in the style of `Character.fromMap`: never throws on legacy or
  /// hand-edited data.
  factory ElectronicsDays.fromMap(Object? raw) {
    if (raw is! Map) return const ElectronicsDays();
    final rawDays = raw['days'];
    final num? n = rawDays is num
        ? rawDays
        : rawDays is String
            ? num.tryParse(rawDays.trim())
            : null;
    // Non-finite values (NaN, +/-Infinity) cannot be truncated to an int.
    final days = (n != null && n.isFinite) ? n.toInt() : 0;
    final rawClaimed = raw['claimed'];
    final claimed = rawClaimed is List
        ? (rawClaimed.map(parseDay).whereType<int>().toSet().toList()..sort())
        : <int>[];
    return ElectronicsDays(
      days: days,
      asOf: parseDay(raw['as_of']) ?? kElectronicsDaysEpoch,
      claimed: claimed,
    );
  }

  Map<String, dynamic> toMap() => {
        'days': days,
        'as_of': formatDay(asOf),
        'claimed': [for (final d in claimed) formatDay(d)],
      };

  /// Full days in [asOf, today). Zero when [asOf] is today or later.
  int accrued(int today) => math.max(0, today - asOf);

  int available(int today) => days + accrued(today);

  bool isClaimed(int day) => claimed.contains(day);

  ElectronicsDays settle(int today) => ElectronicsDays(
        days: available(today),
        asOf: math.max(asOf, today),
        claimed: claimed,
      );

  /// An admin's hand-set value: what [available] reads today.
  ElectronicsDays withValue(int value, int today) => ElectronicsDays(
        days: math.max(0, value),
        asOf: math.max(asOf, today),
        claimed: claimed,
      );

  /// Spends [day]: costs one, and [day] itself never adds one. A [day] that
  /// already passed (late approval) has accrued, so it is taken back too --
  /// except days before [kElectronicsDaysEpoch], which never accrued, so they
  /// cost only the claim. Claiming a date already in [claimed] changes nothing.
  ElectronicsDays applyClaim(int day, int today) {
    if (isClaimed(day)) return this;
    final settled = settle(today);
    var nextDays = settled.days - 1;
    var nextAsOf = settled.asOf;
    if (day < today) {
      if (day >= kElectronicsDaysEpoch) nextDays -= 1;
    } else {
      nextAsOf = math.max(nextAsOf, day + 1);
    }
    final all = [...claimed, day]..sort();
    final trimmed =
        all.length > maxClaimed ? all.sublist(all.length - maxClaimed) : all;
    return ElectronicsDays(
      days: math.max(0, nextDays),
      asOf: nextAsOf,
      claimed: trimmed,
    );
  }

  ElectronicsCardState stateFor(int today, {required bool hasPendingClaim}) {
    if (isClaimed(today)) return ElectronicsCardState.claimed;
    if (hasPendingClaim) return ElectronicsCardState.pending;
    if (available(today) <= 0) return ElectronicsCardState.empty;
    return ElectronicsCardState.charging;
  }
}
