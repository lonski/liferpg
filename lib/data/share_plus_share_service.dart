import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'share_service.dart';

/// Real implementation, backed by the native Android share sheet.
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> share({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (imageBytes == null) {
      await SharePlus.instance.share(ShareParams(text: text));
      return;
    }
    final name = imageName ?? 'liferpg.png';
    await SharePlus.instance.share(ShareParams(
      text: text,
      files: [XFile.fromData(imageBytes, mimeType: 'image/png', name: name)],
      fileNameOverrides: [name],
    ));
  }
}
