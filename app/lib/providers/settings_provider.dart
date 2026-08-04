import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db;
  List<String> _selectedPairs = [];
  bool _isAnalysisRunning = false;
  String _serverUrl = AppConfig.serverBaseUrl;

  List<String> get selectedPairs => _selectedPairs;
  bool get isAnalysisRunning => _isAnalysisRunning;
  String get serverUrl => _serverUrl;

  SettingsProvider(this._db);

  Future<void> loadSettings() async {
    _selectedPairs = _db.getSelectedPairs().toList();
    _isAnalysisRunning = _db.getIsAnalysisRunning();
    _serverUrl = _db.getServerUrl();
    notifyListeners();
  }

  Future<void> togglePair(String pair) async {
    if (_selectedPairs.contains(pair)) {
      _selectedPairs.remove(pair);
    } else {
      _selectedPairs.add(pair);
    }
    await _db.setSelectedPairs(_selectedPairs);
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    await _db.setServerUrl(url);
    notifyListeners();
  }

  Future<void> setAnalysisRunning(bool running) async {
    _isAnalysisRunning = running;
    await _db.setIsAnalysisRunning(running);
    notifyListeners();
  }
}
