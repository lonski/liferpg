import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quest_deep_link.dart';
import '../../models/quest.dart';
import '../../providers/quest_providers.dart';
import 'quest_card.dart';

/// Captures [quest]'s card as a PNG and hands it, plus a caption carrying the
/// quest's title and its `liferpg://quest/<id>` deep link, to
/// [questShareServiceProvider] -- which opens Android's native share sheet.
/// A failed capture (rare -- see `_captureQuestCardImage`) degrades to a
/// text-only share rather than failing the whole action.
Future<void> shareQuest(BuildContext context, WidgetRef ref, Quest quest) async {
  final service = ref.read(questShareServiceProvider);
  final text = '${quest.title}\n${questDeepLink(quest.id)}';
  Uint8List? imageBytes;
  try {
    imageBytes = await _captureQuestCardImage(context, quest);
  } catch (e) {
    debugPrint('Falling back to a text-only share for quest ${quest.id}: $e');
  }
  await service.share(
    text: text,
    imageBytes: imageBytes,
    imageName: 'quest-${quest.id}.png',
  );
}

/// Renders an action-free, fixed-width copy of [quest]'s card offscreen (an
/// [Overlay] entry positioned well outside the viewport) so its pixels don't
/// depend on whatever width the caller's card happened to be laid out at,
/// then rasterises it via [RenderRepaintBoundary]. Two frames are awaited:
/// the first mounts and lays the copy out, the second guarantees it has
/// actually painted before `toImage` runs.
Future<Uint8List?> _captureQuestCardImage(BuildContext context, Quest quest) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -9999,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 360,
          child: RepaintBoundary(key: boundaryKey, child: QuestCard(quest: quest)),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
