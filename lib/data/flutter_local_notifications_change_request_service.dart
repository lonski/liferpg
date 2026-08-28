import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'change_request_notification_service.dart';

/// Real system-tray-backed implementation. Kept free of any `features/`
/// import -- what a tapped notification opens is decided by [onTap], supplied
/// by `main.dart`, not by this data-layer class.
class FlutterLocalNotificationsChangeRequestService
    implements ChangeRequestNotificationService {
  FlutterLocalNotificationsChangeRequestService(this._plugin, {this.onTap});

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String payload)? onTap;

  static const _channel = AndroidNotificationChannel(
    'change_requests',
    'Prośby o zmiany',
    description: 'Nowe prośby o zmiany i decyzje w Twoich prośbach',
    importance: Importance.high,
  );

  Future<void> init() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );
  }

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) =>
      _plugin.show(
        id: id.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name),
        ),
        payload: payload,
      );
}
