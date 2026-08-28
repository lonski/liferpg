/// The seam through which the notification glue provider posts an actual
/// system-tray notification, and through which tests swap in a fake. Kept
/// deliberately thin -- message text and which events fire are decided by
/// the glue provider, not here.
abstract class ChangeRequestNotificationService {
  /// Requests the runtime notification permission (Android 13+). A no-op on
  /// platforms/versions that don't require it.
  Future<void> requestPermission();

  /// Posts a system-tray notification. [id] identifies the underlying
  /// change request, so re-showing the same [id] replaces rather than stacks.
  /// [payload] names the screen to open on tap.
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  });
}
