import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/character.dart';
import '../../providers/share_providers.dart';
import '../share/widget_capture.dart';
import 'achievement_share_card.dart';

typedef WidgetCapture = Future<Uint8List?> Function(
  BuildContext context,
  Widget child, {
  double width,
});

/// Worded so the name stays in the nominative: names can't be declined
/// automatically (`Odznaka dla Zosia` would be wrong). No link -- a badge is
/// only readable by people who can see the character.
String achievementShareCaption(String characterName, Achievement a) =>
    '$characterName — odznaka „${a.title}”'
    '${a.event == null ? '' : ' (${a.event})'}';

/// Shares [achievement] as an image of [AchievementShareCard] plus a caption;
/// a failed capture degrades to the caption alone, as quests do.
Future<void> shareAchievement(
  BuildContext context,
  WidgetRef ref,
  Character character,
  Achievement achievement, {
  WidgetCapture capture = captureWidgetImage,
}) async {
  final service = ref.read(shareServiceProvider);
  Uint8List? imageBytes;
  try {
    imageBytes = await capture(
      context,
      AchievementShareCard(character: character, achievement: achievement),
    );
  } catch (e) {
    debugPrint('Text-only share for achievement ${achievement.id}: $e');
  }
  await service.share(
    text: achievementShareCaption(character.name, achievement),
    imageBytes: imageBytes,
    imageName: 'odznaka-${achievement.id}.png',
  );
}
