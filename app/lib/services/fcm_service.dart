import 'dart:convert';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../services/notification_service.dart';

class FcmService extends ChangeNotifier {
  final DatabaseService _db;
  final NotificationService _notifications;
  FirebaseMessaging? _messaging;
  String? _token;
  bool _available = false;
  String _registerError = '';

  FcmService(this._db, this._notifications);

  String? get token => _token;
  bool get available => _available;
  String get registerError => _registerError;

  Future<void> init() async {
    try {
      _messaging = FirebaseMessaging.instance;
      _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging!.requestPermission(alert: true, badge: true, sound: true);
_token = await _messaging!.getToken();
_available = true;
_registerError = '';
notifyListeners();

      _messaging!.onTokenRefresh.listen((t) {
        _token = t;
        registerWithServer();
      });

      // Foreground messages are not auto-displayed; surface them as local
      // notifications so pushes are visible while the app is open.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ??
            message.data['title'] ??
            'SMC Scalp';
        final body = message.notification?.body ??
            message.data['body'] ??
            '';
        _notifications.showFcm(title: title, body: body);
      });
    } on FirebaseException catch (e) {
      _available = false;
      _registerError = e.code == 'no-app'
          ? 'Firebase not configured (missing google-services.json)'
          : 'FCM error: ${e.code}';
      notifyListeners();
    } catch (e) {
      _available = false;
      _registerError = 'FCM unavailable: $e';
      notifyListeners();
    }
  }

  Future<void> registerWithServer() async {
    if (!_available || _token == null) return;
    final serverUrl = _db.getServerUrl();
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': _token}),
      );
      _registerError = response.statusCode == 200
          ? ''
          : 'Register failed (${response.statusCode})';
    } catch (e) {
      _registerError = 'Server unreachable: $e';
    }
    notifyListeners();
  }
}
