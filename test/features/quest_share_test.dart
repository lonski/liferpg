import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_share_service.dart';
import 'package:liferpg/features/quests/quest_share.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';
import 'package:liferpg/providers/quest_providers.dart';

const _quest = Quest(
  id: 'q1',
  title: 'Posprzątaj garaż',
  posterUid: 'u1',
  posterEmail: 'ala@example.com',
  posterName: 'Ala',
  status: QuestStatus.open,
  reward: ChangeSet(currentXp: 50),
);

class _Call {
  _Call(this.text, this.imageBytes);
  final String text;
  final Uint8List? imageBytes;
}

class _FakeQuestShareService implements QuestShareService {
  final calls = <_Call>[];

  @override
  Future<void> share({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    calls.add(_Call(text, imageBytes));
  }
}

void main() {
  testWidgets('shareQuest shares the title, deep link, and a captured image',
      (tester) async {
    final fakeService = _FakeQuestShareService();
    late BuildContext capturedContext;
    late WidgetRef capturedRef;

    await tester.pumpWidget(ProviderScope(
      overrides: [questShareServiceProvider.overrideWithValue(fakeService)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          capturedContext = context;
          capturedRef = ref;
          return const SizedBox();
        }),
      ),
    ));

    // shareQuest waits on WidgetsBinding.endOfFrame (twice) and then on
    // RenderRepaintBoundary.toImage -- a mix of test-driven frame pumps and
    // the engine's real rasterizer. Drive both from inside runAsync with a
    // bounded pump loop rather than a fixed pump count, so a genuine
    // regression fails fast instead of hanging the test run.
    final result = shareQuest(capturedContext, capturedRef, _quest);
    var done = false;
    unawaited(result.whenComplete(() => done = true));
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(Duration.zero);
      }
    });
    expect(done, isTrue, reason: 'shareQuest did not complete');

    expect(fakeService.calls, hasLength(1));
    final call = fakeService.calls.single;
    expect(call.text, contains('Posprzątaj garaż'));
    expect(call.text, contains('liferpg://quest/q1'));
    expect(call.imageBytes, isNotNull);
    expect(call.imageBytes, isNotEmpty);
  });
}
