import 'dart:typed_data';

/// The seam through which `shareQuest` hands off to Android's native share
/// sheet, and through which tests swap in a fake -- same shape as
/// `ChangeRequestNotificationService`. Kept thin: image bytes are optional so
/// a failed capture can still fall back to a text-only share.
abstract class QuestShareService {
  Future<void> share({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
  });
}
