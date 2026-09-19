import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/models/alert.dart';

/// Raises the local notifications the manager phone shows.
///
/// Used by both delivery paths: an incoming FCM message in the foreground,
/// and the polling fallback that runs when Firebase is not configured. Keeping
/// one implementation means the notification looks and behaves the same either
/// way, and there is a single place that knows the deep-link payload format.
class LocalNotificationService {
  LocalNotificationService();

  static const String _channelId = 'hornet_alerts';
  static const String _channelName = '말벌 경보';
  static const String _channelDescription = '벌통에서 말벌 집단 공격 징후가 감지되면 알립니다.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  /// Emits the alert id whenever a notification is tapped.
  final StreamController<String> _taps = StreamController<String>.broadcast();

  Stream<String> get onTapped => _taps.stream;

  /// Prepares the plugin and the Android channel.
  ///
  /// Returns `false` rather than throwing when the platform refuses, so a
  /// missing notification permission can never take the app down.
  Future<bool> initialise() async {
    if (_initialised) return true;

    try {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: _handleResponse,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();

      _initialised = true;
      return true;
    } on Object catch (error) {
      debugPrint('LocalNotificationService: initialisation failed — $error');
      return false;
    }
  }

  /// Shows a notification for a newly seen alert.
  Future<void> showAlert(AlertSummary alert) async {
    if (!await initialise()) return;

    try {
      await _plugin.show(
        id: alert.id.hashCode & 0x7fffffff,
        title: '[${alert.severity.label}] ${alert.hiveName}',
        body: alert.message,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(<String, String>{'alertId': alert.id}),
      );
    } on Object catch (error) {
      debugPrint('LocalNotificationService: show failed — $error');
    }
  }

  /// The alert id from a notification that launched the app, if any.
  Future<String?> launchAlertId() async {
    try {
      final NotificationAppLaunchDetails? details =
          await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return _alertIdFrom(details.notificationResponse?.payload);
    } on Object catch (error) {
      debugPrint('LocalNotificationService: launch details failed — $error');
      return null;
    }
  }

  void _handleResponse(NotificationResponse response) {
    final String? alertId = _alertIdFrom(response.payload);
    if (alertId != null && !_taps.isClosed) {
      _taps.add(alertId);
    }
  }

  static String? _alertIdFrom(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final Object? id = decoded['alertId'];
        if (id is String && id.isNotEmpty) return id;
      }
    } on FormatException {
      // A payload we did not write; ignore it rather than crashing.
    }
    return null;
  }

  Future<void> dispose() async {
    await _taps.close();
  }
}
