import 'dart:typed_data';

/// The seam through which the app hands an image + caption to Android's
/// native share sheet (quests and achievements), and through which tests swap
/// in a fake. Image bytes are optional so a failed capture can still fall
/// back to a text-only share.
abstract class ShareService {
  Future<void> share({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
  });
}
