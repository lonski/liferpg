import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quest_deep_link.dart';
import '../../models/quest.dart';
import '../../providers/share_providers.dart';
import '../share/widget_capture.dart';
import 'quest_card.dart';

/// Captures [quest]'s card as a PNG and hands it, plus a caption carrying the
/// quest's title and its deep link, to [shareServiceProvider] -- which opens
/// Android's native share sheet. A failed capture (rare) degrades to a
/// text-only share rather than failing the whole action.
Future<void> shareQuest(BuildContext context, WidgetRef ref, Quest quest) async {
  final service = ref.read(shareServiceProvider);
  final text = '${quest.title}\n${questDeepLink(quest.id)}';
  Uint8List? imageBytes;
  try {
    imageBytes = await captureWidgetImage(context, QuestCard(quest: quest));
  } catch (e) {
    debugPrint('Falling back to a text-only share for quest ${quest.id}: $e');
  }
  await service.share(
    text: text,
    imageBytes: imageBytes,
    imageName: 'quest-${quest.id}.png',
  );
}
