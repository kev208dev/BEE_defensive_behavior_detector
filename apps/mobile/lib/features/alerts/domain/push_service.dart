import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/requests.dart';

/// The alert id carried by a push, if it is one of ours.
String? alertIdFromPush(Map<String, dynamic> data) {
  final Object? id = data['alertId'];
  return id is String && id.isNotEmpty ? id : null;
}

/// Firebase Cloud Messaging integration.
///
/// **Every entry point here is failure-tolerant on purpose.** A phone with no
/// `google-services.json`, no network, or a user who declined notification
/// permission must still run the app — so initialisation returns a bool rather
/// than throwing, and the polling fallback in [AlertWatcher] covers delivery
/// when this is unavailable.
class PushService {
  PushService(this._api);

  final ApiClient _api;

  bool _available = false;

  /// Emits the alert id of a push the user tapped.
  final StreamController<String> _opened = StreamController<String>.broadcast();

  /// Emits alerts that arrived while the app was in the foreground, where the
  /// OS does not show a notification for us.
  final StreamController<Map<String, dynamic>> _foreground =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<String> get onOpened => _opened.stream;

  Stream<Map<String, dynamic>> get onForegroundMessage => _foreground.stream;

  /// Whether FCM initialised successfully.
  bool get isAvailable => _available;

  /// Initialises Firebase and wires the three delivery paths.
  ///
  /// Returns `false` when Firebase is unconfigured or unavailable, which is a
  /// supported state — not an error.
  Future<bool> initialise() async {
    if (!AppConfig.enableFirebase) {
      debugPrint('PushService: Firebase disabled by configuration.');
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } on Object catch (error) {
      // The overwhelmingly common cause is a missing google-services.json /
      // GoogleService-Info.plist. Say so plainly and carry on.
      debugPrint(
        'PushService: Firebase is not configured ($error). '
        'Falling back to alert polling.',
      );
      return false;
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      await messaging.requestPermission();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

      // A push that launched the app from terminated.
      final RemoteMessage? initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpened(initial);

      _available = true;
      return true;
    } on Object catch (error) {
      debugPrint('PushService: messaging setup failed — $error');
      return false;
    }
  }

  /// Registers this phone's FCM token with the backend.
  ///
  /// Also subscribes to token refreshes, because a token that rotates without
  /// being re-registered silently stops receiving alerts.
  Future<void> registerToken({required String platform}) async {
    if (!_available) return;

    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _send(token, platform);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (String refreshed) => unawaited(_send(refreshed, platform)),
      );
    } on Object catch (error) {
      debugPrint('PushService: token registration failed — $error');
    }
  }

  Future<void> _send(String token, String platform) async {
    try {
      await _api.registerPushToken(
        PushTokenRequest(token: token, platform: platform),
      );
    } on Object catch (error) {
      debugPrint('PushService: could not register token with backend — $error');
    }
  }

  void _handleForeground(RemoteMessage message) {
    if (_foreground.isClosed) return;
    _foreground.add(message.data);
  }

  void _handleOpened(RemoteMessage message) {
    final String? alertId = alertIdFromPush(message.data);
    if (alertId != null && !_opened.isClosed) {
      _opened.add(alertId);
    }
  }

  Future<void> dispose() async {
    await _opened.close();
    await _foreground.close();
  }
}
