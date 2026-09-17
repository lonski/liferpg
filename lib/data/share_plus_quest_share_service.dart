import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'quest_share_service.dart';

/// Real implementation, backed by the native Android share sheet.
class SharePlusQuestShareService implements QuestShareService {
  const SharePlusQuestShareService();

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
    final name = imageName ?? 'quest.png';
    await SharePlus.instance.share(ShareParams(
      text: text,
      files: [XFile.fromData(imageBytes, mimeType: 'image/png', name: name)],
      fileNameOverrides: [name],
    ));
  }
}
