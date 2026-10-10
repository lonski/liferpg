import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/share_service.dart';
import 'package:liferpg/features/achievements/achievement_share.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/share_providers.dart';

import 'achievements_test_support.dart';

class FakeShareService implements ShareService {
  final calls = <(String, Uint8List?)>[];

  @override
  Future<void> share({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
  }) async =>
      calls.add((text, imageBytes));
}

final zosia =
    Character.fromMap('c1', zosiaCharacter(achievements: [achievementMap()]));

Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester, FakeShareService service) async {
  late BuildContext context;
  late WidgetRef ref;
  await tester.pumpWidget(ProviderScope(
    overrides: [shareServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: Consumer(builder: (c, r, _) {
        context = c;
        ref = r;
        return const SizedBox();
      }),
    ),
  ));
  return (context, ref);
}

void main() {
  test('caption keeps the name in the nominative and adds the event', () {
    expect(
      achievementShareCaption('Zosia', zosia.achievements.single),
      'Zosia — odznaka „II miejsce” (Wojewódzki Konkurs Recytatorski)',
    );
  });

  testWidgets('shares a captured card image with the caption', (tester) async {
    final service = FakeShareService();
    final (context, ref) = await pumpHost(tester, service);
    final result =
        shareAchievement(context, ref, zosia, zosia.achievements.single);
    var done = false;
    unawaited(result.whenComplete(() => done = true));
    // Same bounded pump loop as quest_share_test: capture mixes test frames
    // with the real rasterizer.
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(Duration.zero);
      }
    });
    expect(done, isTrue);
    expect(service.calls.single.$1, contains('II miejsce'));
    expect(service.calls.single.$2, isNotEmpty);
  });

  testWidgets('a failed capture falls back to text only', (tester) async {
    final service = FakeShareService();
    final (context, ref) = await pumpHost(tester, service);
    await shareAchievement(
      context,
      ref,
      zosia,
      zosia.achievements.single,
      capture: (context, child, {double width = 360}) =>
          throw StateError('no frame'),
    );
    expect(service.calls.single.$2, isNull);
    expect(service.calls.single.$1, startsWith('Zosia — odznaka'));
  });
}
