import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/share_plus_share_service.dart';
import '../data/share_service.dart';

/// Overridden with a fake in tests, same seam pattern as
/// `changeRequestNotificationServiceProvider`.
final shareServiceProvider = Provider<ShareService>(
  (ref) => const SharePlusShareService(),
);
