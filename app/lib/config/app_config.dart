class AppConfig {
  static const String baseUrl = 'https://biquote.io';
  static const int maxCandlesPerRequest = 1000;
  static const int analysisIntervalSeconds = 30;

  static const List<String> defaultPairs = [
    'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF',
    'USDCAD', 'AUDUSD', 'NZDUSD', 'XAUUSD', 'XAGUSD', 'BTCUSD',
  ];

  // ---- Strategy knobs ----
  static const int swingLookback15m = 100;
  static const int swingLookback5m = 200;
  static const int swingLookback1m = 300;
  static const int poiLookback15m = 100;
  static const int sweepLookbackBars = 5;
  static const double sweepBufferPips = 5.0;

  static const int atrPeriod = 14;
  static const double displacementAtrMultiplier = 1.0;
  static const double eqToleranceAtrMultiplier = 0.5;

  static const double sweepSlMultiplier = 1.5;
  static const double metalSlAtrMultiplier = 0.25;
  static const double cryptoSlAtrMultiplier = 0.25;
  static const double minTp1Rrr = 2.0;
  static const double minTp2Rrr = 2.0;
  static const double partialClosePercent = 0.5;
  static const double beBufferPips = 0.5;

  // ---- No-trade filters ----
  static const int retracementCandleLimit = 20;
  static const double maxSpreadFractionOfSl = 0.15;
  static const int newsWindowMinutes = 30;
  static const List<String> newsCountries = ['US', 'EU', 'GB'];

  // ---- News calendar cache ----
  static const int newsCacheRefreshMinutes = 180;
  static const int newsLookaheadHours = 12;
  static const int newsLookbackHours = 2;

  // ---- Sessions (UTC hour windows) ----
  static const List<List<int>> sessionWindowsUtc = [
    [0, 8],
    [8, 16],
    [16, 24],
  ];

  // ---- Server / FCM ----
  static const String serverBaseUrl = 'https://smc-scalp-server.onrender.com';

  static bool isMetal(String symbol) =>
      symbol == 'XAUUSD' || symbol == 'XAGUSD' ||
      symbol == 'XPTUSD' || symbol == 'XPDUSD';

  static bool isCrypto(String symbol) =>
      symbol == 'BTCUSD' || symbol == 'ETHUSD';

  static double pipValue(String symbol) {
    if (symbol == 'BTCUSD' || symbol.contains('XBT')) return 1.0;
    if (symbol == 'ETHUSD') return 0.10;
    if (isMetal(symbol)) return 0.10;
    if (symbol.contains('JPY')) return 0.01;
    return 0.0001;
  }
}
