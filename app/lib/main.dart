import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/analysis_provider.dart';
import 'providers/performance_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/signal_provider.dart';
import 'services/api_client.dart';
import 'services/database_service.dart';
import 'services/fcm_service.dart';
import 'services/news_service.dart';
import 'services/notification_service.dart';
import 'services/web_socket_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final dbService = DatabaseService();
  await dbService.init();

  final notificationService = NotificationService();
  await notificationService.init();

  final apiClient = ApiClient();
  final webSocket = WebSocketService();
  final newsService = NewsService(apiClient);

  final fcmService = FcmService(dbService, notificationService);
  await fcmService.init();

  final signalProvider = SignalProvider(dbService);
  final settingsProvider = SettingsProvider(dbService);
  final performanceProvider = PerformanceProvider(dbService);

  signalProvider.loadSignals();
  await settingsProvider.loadSettings();
  performanceProvider.loadTrades();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: signalProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(
          create: (_) => AnalysisProvider(
            apiClient,
            signalProvider,
            settingsProvider,
            newsService,
            notificationService,
            performanceProvider,
            webSocket,
          ),
        ),
        ChangeNotifierProvider.value(value: performanceProvider),
        ChangeNotifierProvider.value(value: fcmService),
      ],
      child: const SmcScalpApp(),
    ),
  );
}
