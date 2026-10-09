import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/electronics_days.dart';

int d(String s) => parseDay(s)!;

void main() {
  group('day helpers', () {
    test('format/parse round-trip', () {
      expect(formatDay(d('2026-10-09')), '2026-10-09');
      expect(formatDay(kElectronicsDaysEpoch), '2026-10-10');
    });

    test('parseDay rejects malformed input', () {
      expect(parseDay('2026-02-30'), isNull);
      expect(parseDay('abc'), isNull);
      expect(parseDay('2026-1-1'), isNull);
      expect(parseDay(42), isNull);
      expect(parseDay(null), isNull);
    });

    test('dayOf uses the local calendar date and survives DST', () {
      // 2026-10-25 is the EU DST end; a 25-hour local day.
      expect(dayOf(DateTime(2026, 10, 25, 0, 30)),
          dayOf(DateTime(2026, 10, 25, 23, 30)));
      expect(dayOf(DateTime(2026, 10, 26, 0, 1)) - dayOf(DateTime(2026, 10, 25, 23, 59)), 1);
      expect(formatDay(dayOf(DateTime(2026, 10, 9, 23, 59))), '2026-10-09');
    });

    test('dayFraction is the elapsed share of the local day', () {
      expect(dayFraction(DateTime(2026, 10, 9)), 0.0);
      expect(dayFraction(DateTime(2026, 10, 9, 12)), closeTo(0.5, 0.0001));
    });
  });

  group('accrual', () {
    test('a fresh character starts at 0 on the epoch and earns a day per full day', () {
      const e = ElectronicsDays();
      expect(e.available(kElectronicsDaysEpoch - 5), 0);
      expect(e.available(kElectronicsDaysEpoch), 0);
      expect(e.available(kElectronicsDaysEpoch + 3), 3);
    });

    test('adds full days since as_of to the stored count', () {
      final e = ElectronicsDays(days: 5, asOf: d('2026-10-20'));
      expect(e.available(d('2026-10-23')), 8);
    });

    test('as_of in the future accrues nothing', () {
      final e = ElectronicsDays(days: 4, asOf: d('2026-10-23'));
      expect(e.accrued(d('2026-10-22')), 0);
      expect(e.available(d('2026-10-22')), 4);
    });

    test('settle folds accrual into days without changing available', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final s = e.settle(d('2026-10-22'));
      expect(s.days, 5);
      expect(s.asOf, d('2026-10-22'));
      expect(s.available(d('2026-10-24')), e.available(d('2026-10-24')));
    });
  });

  group('writes', () {
    test('withValue sets today\'s value and clamps at 0', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final v = e.withValue(9, d('2026-10-22'));
      expect(v.available(d('2026-10-22')), 9);
      expect(v.available(d('2026-10-23')), 10);
      expect(e.withValue(-4, d('2026-10-22')).available(d('2026-10-22')), 0);
    });

    test('claiming today costs one and today never accrues', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final c = e.applyClaim(d('2026-10-22'), d('2026-10-22'));
      expect(c.available(d('2026-10-22')), 4); // 5 settled - 1
      expect(c.available(d('2026-10-23')), 4); // 22nd not accrued
      expect(c.available(d('2026-10-24')), 5);
      expect(c.isClaimed(d('2026-10-22')), isTrue);
    });

    test('a late approval takes back the day that already accrued', () {
      // Tapped on the 21st, accepted on the 22nd.
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'));
      final c = e.applyClaim(d('2026-10-21'), d('2026-10-22'));
      expect(c.available(d('2026-10-22')), 3); // 3 + 20th, 21st claimed: -1, not accrued
      expect(c.available(d('2026-10-23')), 4);
    });

    test('claiming an already-claimed date is a no-op', () {
      final e = ElectronicsDays(days: 3, asOf: d('2026-10-20'))
          .applyClaim(d('2026-10-22'), d('2026-10-22'));
      final again = e.applyClaim(d('2026-10-22'), d('2026-10-23'));
      expect(again.days, e.days);
      expect(again.asOf, e.asOf);
      expect(again.claimed, e.claimed);
    });

    test('claiming at zero clamps at zero', () {
      final e = ElectronicsDays(days: 0, asOf: d('2026-10-22'));
      expect(e.applyClaim(d('2026-10-22'), d('2026-10-22')).available(d('2026-10-22')), 0);
    });

    test('a pre-epoch claim costs only the claim: that day never accrued', () {
      const e = ElectronicsDays(days: 5, asOf: kElectronicsDaysEpoch);
      final c = e.applyClaim(kElectronicsDaysEpoch - 1, kElectronicsDaysEpoch);
      expect(c.available(kElectronicsDaysEpoch), 4);
    });

    test('keeps only the 31 most recent claimed dates', () {
      var e = ElectronicsDays(days: 100, asOf: d('2026-10-01'));
      for (var i = 0; i < 40; i++) {
        final day = d('2026-10-01') + i;
        e = e.applyClaim(day, day);
      }
      expect(e.claimed, hasLength(31));
      expect(e.claimed.first, d('2026-10-01') + 9);
      expect(e.claimed.last, d('2026-10-01') + 39);
    });
  });

  group('map', () {
    test('missing or non-map reads as the default', () {
      expect(ElectronicsDays.fromMap(null).available(kElectronicsDaysEpoch + 2), 2);
      expect(ElectronicsDays.fromMap('x').days, 0);
    });

    test('non-finite days read as 0 instead of throwing', () {
      expect(ElectronicsDays.fromMap({'days': double.nan}).days, 0);
      expect(ElectronicsDays.fromMap({'days': double.infinity}).days, 0);
      expect(ElectronicsDays.fromMap({'days': 'Infinity'}).days, 0);
      expect(ElectronicsDays.fromMap({'days': 'NaN'}).days, 0);
    });

    test('tolerates stringly and garbage values', () {
      final e = ElectronicsDays.fromMap({
        'days': '7',
        'as_of': 'garbage',
        'claimed': ['2026-10-11', 5, 'x', '2026-10-11'],
      });
      expect(e.days, 7);
      expect(e.asOf, kElectronicsDaysEpoch);
      expect(e.claimed, [d('2026-10-11')]);
    });

    test('toMap round-trips', () {
      final e = ElectronicsDays(days: 4, asOf: d('2026-10-23'), claimed: [d('2026-10-22')]);
      expect(e.toMap(), {'days': 4, 'as_of': '2026-10-23', 'claimed': ['2026-10-22']});
      final back = ElectronicsDays.fromMap(e.toMap());
      expect(back.days, 4);
      expect(back.asOf, d('2026-10-23'));
      expect(back.claimed, [d('2026-10-22')]);
    });
  });

  group('stateFor', () {
    final today = d('2026-10-22');
    test('claimed wins over everything', () {
      final e = ElectronicsDays(days: 3, asOf: today, claimed: [today]);
      expect(e.stateFor(today, hasPendingClaim: true), ElectronicsCardState.claimed);
    });
    test('pending wins over empty', () {
      final e = ElectronicsDays(days: 0, asOf: today);
      expect(e.stateFor(today, hasPendingClaim: true), ElectronicsCardState.pending);
    });
    test('empty at zero, charging otherwise', () {
      expect(ElectronicsDays(days: 0, asOf: today).stateFor(today, hasPendingClaim: false),
          ElectronicsCardState.empty);
      expect(ElectronicsDays(days: 2, asOf: today).stateFor(today, hasPendingClaim: false),
          ElectronicsCardState.charging);
    });
  });
}
