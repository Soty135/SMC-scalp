import 'package:flutter/material.dart';

import 'models/trade_signal.dart';
import 'screens/dashboard_screen.dart';
import 'screens/performance_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signal_detail_screen.dart';
import 'screens/signals_screen.dart';

class SmcScalpApp extends StatelessWidget {
  const SmcScalpApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0F14);
    const surface = Color(0xFF131A22);
    const border = Color(0xFF1F2833);
    const accent = Color(0xFF00E5A0);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );

    return MaterialApp(
      title: 'SMC Scalp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        fontFamily: 'monospace',
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        dividerColor: border,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const DashboardScreen());
          case '/signals':
            return MaterialPageRoute(builder: (_) => const SignalsScreen());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case '/performance':
            return MaterialPageRoute(
                builder: (_) => const PerformanceScreen());
          case '/signal-detail':
            final signal = settings.arguments as TradeSignal;
            return MaterialPageRoute(
              builder: (_) => SignalDetailScreen(signal: signal),
            );
          default:
            return MaterialPageRoute(builder: (_) => const DashboardScreen());
        }
      },
    );
  }
}
