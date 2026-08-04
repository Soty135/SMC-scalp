import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_config.dart';
import '../models/trade_result.dart';
import '../models/trade_signal.dart';
import '../models/timeframe.dart';

class DatabaseService {
  static const String _signalsBoxName = 'tradeSignals';
  static const String _settingsBoxName = 'settings';
  static const String _tradesBoxName = 'tradeResults';
  static const int _schemaVersion = 1;

  Box<TradeSignal>? _signalsBox;
  Box? _settingsBox;
  Box<TradeResult>? _tradesBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SignalTypeAdapter());
    Hive.registerAdapter(SignalStatusAdapter());
    Hive.registerAdapter(TimeframeAdapter());
    Hive.registerAdapter(TradeSignalAdapter());
    Hive.registerAdapter(TradeOutcomeAdapter());
    Hive.registerAdapter(TradeResultAdapter());

    _signalsBox = await Hive.openBox<TradeSignal>(_signalsBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _tradesBox = await Hive.openBox<TradeResult>(_tradesBoxName);

    final storedVersion = _settingsBox?.get('schemaVersion', defaultValue: 0) as int;
    if (storedVersion < _schemaVersion) {
      await _signalsBox?.clear();
      await _tradesBox?.clear();
      await _settingsBox?.put('schemaVersion', _schemaVersion);
    }
  }

  // ---- Signals ----

  List<TradeSignal> getAllSignals() => _signalsBox?.values.toList() ?? [];

  Future<void> saveSignal(TradeSignal signal) async {
    await _signalsBox?.put(signal.id, signal);
  }

  Future<void> updateSignal(TradeSignal signal) async {
    await _signalsBox?.put(signal.id, signal);
  }

  Future<void> deleteSignal(String id) async {
    await _signalsBox?.delete(id);
  }

  Future<void> clearAllSignals() async {
    await _signalsBox?.clear();
  }

  // ---- Settings ----

  T? getSetting<T>(String key) => _settingsBox?.get(key) as T?;

  Future<void> setSetting<T>(String key, T value) async {
    await _settingsBox?.put(key, value);
  }

  List<String> getSelectedPairs() {
    final pairs = getSetting<List<String>>('selectedPairs');
    if (pairs == null || pairs.isEmpty) return AppConfig.defaultPairs;
    return pairs;
  }

  Future<void> setSelectedPairs(List<String> pairs) async {
    await setSetting('selectedPairs', pairs);
  }

  bool getIsAnalysisRunning() => getSetting<bool>('isAnalysisRunning') ?? false;

  Future<void> setIsAnalysisRunning(bool running) async {
    await _settingsBox?.put('isAnalysisRunning', running);
  }

  String getServerUrl() =>
      getSetting<String>('serverUrl') ?? AppConfig.serverBaseUrl;

  Future<void> setServerUrl(String url) async {
    await setSetting('serverUrl', url);
  }

  // ---- Trade results ----

  List<TradeResult> getAllTradeResults() => _tradesBox?.values.toList() ?? [];

  Future<void> saveTradeResult(TradeResult trade) async {
    await _tradesBox?.put(trade.id, trade);
  }

  Future<void> deleteTradeResult(String id) async {
    await _tradesBox?.delete(id);
  }

  Future<void> clearAllTrades() async {
    await _tradesBox?.clear();
  }
}
