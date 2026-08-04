import 'package:flutter/foundation.dart';
import '../models/trade_signal.dart';
import '../services/database_service.dart';

class SignalProvider extends ChangeNotifier {
  final DatabaseService _db;
  List<TradeSignal> _signals = [];
  TradeSignal? _lastSignal;

  List<TradeSignal> get signals => _signals;
  TradeSignal? get lastSignal => _lastSignal;

  SignalProvider(this._db);

  List<TradeSignal> get activeSignals =>
      _signals.where((s) => s.isOpen).toList();

  List<TradeSignal> getSignalsByPair(String pair) =>
      _signals.where((s) => s.pair == pair).toList();

  TradeSignal? byId(String id) {
    for (final s in _signals) {
      if (s.id == id) return s;
    }
    return null;
  }

  void loadSignals() {
    _signals = _db.getAllSignals();
    _signals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<bool> addSignal(TradeSignal signal) async {
    if (_isDuplicate(signal)) return false;

    await _expireOldSetups(signal);

    await _db.saveSignal(signal);
    _signals.insert(0, signal);
    _lastSignal = signal;
    notifyListeners();

    return true;
  }

  Future<bool> updateSignal(TradeSignal signal) async {
    final idx = _signals.indexWhere((s) => s.id == signal.id);
    if (idx == -1) return false;
    await _db.updateSignal(signal);
    _signals[idx] = signal;
    _lastSignal = signal;
    notifyListeners();
    return true;
  }

  Future<void> updateStatus(String id, SignalStatus status) async {
    final s = byId(id);
    if (s == null) return;
    final updated = s.copyWith(status: status);
    await updateSignal(updated);
  }

  Future<void> deleteSignal(String id) async {
    await _db.deleteSignal(id);
    _signals.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _db.clearAllSignals();
    _signals.clear();
    _lastSignal = null;
    notifyListeners();
  }

  /// A new sweep setup for the same pair+type+level is a duplicate while the
  /// previous identical setup is still open. Resolved setups never block.
  bool _isDuplicate(TradeSignal newSignal) {
    const double tolerance = 0.0001;
    for (final s in _signals) {
      if (s.pair != newSignal.pair || s.type != newSignal.type) continue;
      if (!s.isOpen) continue;
      if ((s.sweepExtreme - newSignal.sweepExtreme).abs() < tolerance) {
        return true;
      }
    }
    return false;
  }

  Future<void> _expireOldSetups(TradeSignal newSignal) async {
    final toExpire = <TradeSignal>[];
    for (final s in _signals) {
      if (s.pair == newSignal.pair &&
          s.type == newSignal.type &&
          s.isOpen &&
          s.id != newSignal.id) {
        toExpire.add(s);
      }
    }
    for (final s in toExpire) {
      await updateStatus(s.id, SignalStatus.expired);
    }
  }
}
