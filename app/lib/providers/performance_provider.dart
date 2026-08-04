import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/candle.dart';
import '../models/trade_result.dart';
import '../models/trade_signal.dart';
import '../services/database_service.dart';
import '../smc/trade_monitor.dart';

class PerformanceStats {
  final int totalTrades;
  final int wins;
  final int losses;
  final int open;
  final double winRate;
  final double avgRealizedRrr;
  final Map<String, PairStats> byPair;

  const PerformanceStats({
    this.totalTrades = 0,
    this.wins = 0,
    this.losses = 0,
    this.open = 0,
    this.winRate = 0,
    this.avgRealizedRrr = 0,
    this.byPair = const {},
  });
}

class PairStats {
  final int total;
  final int wins;
  final int losses;
  final double winRate;
  final double avgRrr;

  const PairStats({
    this.total = 0,
    this.wins = 0,
    this.losses = 0,
    this.winRate = 0,
    this.avgRrr = 0,
  });
}

class PerformanceProvider extends ChangeNotifier {
  final DatabaseService _db;
  final Map<String, int> _fillIndices = {};
  List<TradeResult> _trades = [];

  PerformanceProvider(this._db);

  List<TradeResult> get trades => _trades;
  List<TradeResult> get openTrades =>
      _trades.where((t) => t.outcome == TradeOutcome.open).toList();

  void registerFill(String signalId, int fillIndex) {
    _fillIndices[signalId] = fillIndex;
  }

  void loadTrades() {
    _trades = _db.getAllTradeResults();
    _trades.sort((a, b) => b.filledTime.compareTo(a.filledTime));
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _db.clearAllTrades();
    _trades.clear();
    _fillIndices.clear();
    notifyListeners();
  }

  PerformanceStats get stats {
    final closed = _trades
        .where((t) => t.outcome != TradeOutcome.open)
        .toList();
    final wins = closed.where((t) => t.isWin).length;
    final losses = closed.where((t) => !t.isWin).length;
    final open = _trades.where((t) => t.outcome == TradeOutcome.open).length;

    final byPair = <String, PairStats>{};
    final pairs = <String>{};
    for (final t in _trades) {
      pairs.add(t.pair);
    }
    for (final pair in pairs) {
      final pairTrades = _trades.where((x) => x.pair == pair).toList();
      final pairClosed = pairTrades
          .where((x) => x.outcome != TradeOutcome.open)
          .toList();
      final pwins = pairClosed.where((x) => x.isWin).length;
      final pavgRrr = pairClosed.isEmpty
          ? 0.0
          : pairClosed.fold(0.0, (s, x) => s + x.realizedRrr) /
              pairClosed.length;
      byPair[pair] = PairStats(
        total: pairTrades.length,
        wins: pwins,
        losses: pairClosed.length - pwins,
        winRate: pairClosed.isEmpty ? 0 : pwins / pairClosed.length,
        avgRrr: pavgRrr,
      );
    }

    final avgRrr = closed.isEmpty
        ? 0.0
        : closed.fold(0.0, (s, t) => s + t.realizedRrr) / closed.length;

    return PerformanceStats(
      totalTrades: _trades.length,
      wins: wins,
      losses: losses,
      open: open,
      winRate: closed.isEmpty ? 0 : wins / closed.length,
      avgRealizedRrr: avgRrr,
      byPair: byPair,
    );
  }

  Future<TradeResult> openResultForSignal(TradeSignal signal) async {
    final result = TradeResult(
      signalId: signal.id,
      pair: signal.pair,
      type: signal.type,
      entry: signal.entry,
      stopLoss: signal.stopLoss,
      takeProfit1: signal.takeProfit1,
      takeProfit2: signal.takeProfit2,
      partialClosePercent: AppConfig.partialClosePercent,
      risk: signal.risk,
      filledTime: signal.filledTime ?? DateTime.now().toUtc(),
    );
    await _db.saveTradeResult(result);
    _trades.insert(0, result);
    notifyListeners();
    return result;
  }

  Future<List<TradeResult>> monitorTrades(
    List<Candle> candles1m,
    String pair,
  ) async {
    final newlyClosed = <TradeResult>[];
    final openForPair = _trades
        .where((t) => t.pair == pair && t.outcome == TradeOutcome.open)
        .toList();

    for (final trade in openForPair) {
      final fillIndex = _fillIndices[trade.signalId] ?? -1;
      if (fillIndex < 0) continue;

      final outcome = TradeMonitor.checkOutcome(
        candles: candles1m,
        entry: trade.entry,
        sl: trade.stopLoss,
        tp1: trade.takeProfit1,
        tp2: trade.takeProfit2,
        isBullish: trade.type == SignalType.buy,
        fillIndex: fillIndex,
      );
      if (outcome == TradeOutcome.open) continue;

      final updated = trade.copyWith(
        outcome: outcome,
        exitTime: DateTime.now().toUtc(),
        exitPrice: _exitPriceFor(trade, outcome),
        realizedReturn: _realizedReturn(trade, outcome),
      );

      await _db.saveTradeResult(updated);
      final idx = _trades.indexWhere((t) => t.id == trade.id);
      if (idx != -1) _trades[idx] = updated;
      newlyClosed.add(updated);
    }

    if (newlyClosed.isNotEmpty) notifyListeners();
    return newlyClosed;
  }

  double _exitPriceFor(TradeResult t, TradeOutcome o) {
    switch (o) {
      case TradeOutcome.sl_hit:
        return t.stopLoss;
      case TradeOutcome.tp1_hit:
        return t.takeProfit1;
      case TradeOutcome.tp2_hit:
        return t.takeProfit2;
      case TradeOutcome.open:
        return t.entry;
    }
  }

  double _realizedReturn(TradeResult t, TradeOutcome o) {
    final r1 = (t.takeProfit1 - t.entry).abs();
    switch (o) {
      case TradeOutcome.sl_hit:
        return t.risk;
      case TradeOutcome.tp1_hit:
        return r1 * t.partialClosePercent;
      case TradeOutcome.tp2_hit:
        final r2 = t.takeProfit2 > 0 ? (t.takeProfit2 - t.entry).abs() : r1;
        return r1 * t.partialClosePercent + r2 * (1 - t.partialClosePercent);
      case TradeOutcome.open:
        return 0;
    }
  }
}
