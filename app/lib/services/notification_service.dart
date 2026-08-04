import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  int _idCounter = 0;

  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'entry_channel',
        'Entry Signals',
        description: 'Notifications when entry conditions are met',
        importance: Importance.max,
        playSound: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'outcome_channel',
        'Trade Outcomes',
        description: 'Notifications when trades hit SL or TP',
        importance: Importance.max,
        playSound: true,
      ),
    );

    _initialized = true;
  }

  Future<void> showEntrySignal({
    required String pair,
    required String direction,
    required double entry,
    required double stopLoss,
    required double takeProfit1,
    required double takeProfit2,
    required double rrr1,
    required double rrr2,
  }) async {
    await _plugin.show(
      _idCounter++,
      '⚡ $direction $pair — LIMIT ENTRY',
      'Entry: $entry | SL: $stopLoss | TP1: $takeProfit1 (${rrr1.toStringAsFixed(2)}R) | TP2: $takeProfit2 (${rrr2.toStringAsFixed(2)}R)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'entry_channel',
          'Entry Signals',
          channelDescription: 'Notifications when entry conditions are met',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
      ),
    );
  }

  Future<void> showFill({
    required String pair,
    required String direction,
    required double entry,
  }) async {
    await _plugin.show(
      _idCounter++,
      '✅ $direction $pair FILLED',
      'Limit order filled at $entry — SL & TP active',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'entry_channel',
          'Entry Signals',
          channelDescription: 'Notifications when entry conditions are met',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
      ),
    );
  }

  Future<void> showFcm({required String title, required String body}) async {
    await _plugin.show(
      _idCounter++,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'entry_channel',
          'Entry Signals',
          channelDescription: 'Notifications when entry conditions are met',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
      ),
    );
  }

  Future<void> showTradeOutcome({
    required String pair,
    required String outcome,
    required double exitPrice,
  }) async {
    await _plugin.show(
      _idCounter++,
      '🏁 $pair: $outcome',
      'Exited at $exitPrice',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'outcome_channel',
          'Trade Outcomes',
          channelDescription: 'Notifications when trades hit SL or TP',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
      ),
    );
  }
}
