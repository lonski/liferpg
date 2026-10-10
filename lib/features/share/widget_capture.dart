import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [child] offscreen at a fixed [width] (an [Overlay] entry
/// positioned well outside the viewport) so its pixels don't depend on
/// whatever width the caller happened to be laid out at, then rasterises it
/// via [RenderRepaintBoundary]. Two frames are awaited: the first mounts and
/// lays the copy out, the second guarantees it has actually painted before
/// `toImage` runs.
Future<Uint8List?> captureWidgetImage(
  BuildContext context,
  Widget child, {
  double width = 360,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -9999,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          child: RepaintBoundary(key: boundaryKey, child: child),
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
