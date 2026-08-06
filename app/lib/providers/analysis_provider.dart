import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/candle.dart';
import '../models/tick.dart';
import '../models/timeframe.dart';
import '../models/trade_result.dart';
import '../models/trade_signal.dart';
import '../services/api_client.dart';
import '../services/news_service.dart';
import '../services/notification_service.dart';
import '../services/web_socket_service.dart';
import '../smc/sweep_reversal_model.dart';
import '../smc/trade_monitor.dart';
import 'performance_provider.dart';
import 'settings_provider.dart';
import 'signal_provider.dart';

enum AnalysisPhase { scanning, awaitingChoch, awaitingEntry, monitoring }

class _PairState {
  AnalysisPhase phase = AnalysisPhase.scanning;
  SweepContext? ctx;
  ChochResult? choch;
  String? signalId;
  int fillIndex = -1;
  String detail = 'Waiting…';
}

class AnalysisProvider extends ChangeNotifier {
  final ApiClient _api;
  final SignalProvider _signalProvider;
  final SettingsProvider _settingsProvider;
  final NewsService _news;
  final NotificationService _notifications;
  final PerformanceProvider _performance;
  final WebSocketService _webSocket;

  bool _isRunning = false;
  bool _isAnalyzing = false;
  Timer? _timer;
  String _statusMessage = 'Ready';

  final Map<String, double> _currentPrices = {};
  final Map<String, String> _pairStatuses = {};
  final Map<String, Tick> _ticks = {};
  final Map<String, _PairState> _states = {};

  StreamSubscription<Tick>? _tickSub;
  StreamSubscription<WsConnectionState>? _stateSub;
  DateTime _lastTickNotify = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _isRunning;
  bool get isAnalyzing => _isAnalyzing;
  String get statusMessage => _statusMessage;
  bool get isConnected => _webSocket.isConnected;
  WsConnectionState get connectionState => _webSocket.connectionState;
  Map<String, double> get currentPrices => _currentPrices;
  Map<String, String> get pairStatuses => _pairStatuses;

  AnalysisProvider(
    this._api,
    this._signalProvider,
    this._settingsProvider,
    this._news,
    this._notifications,
    this._performance,
    this._webSocket,
  ) {
    _settingsProvider.addListener(_onSettingsChanged);
  }

  // ============================ LIFECYCLE ============================

  Future<void> startAnalysis() async {
    if (_isRunning) return;
    _isRunning = true;
    _statusMessage = 'Analysis running…';

    _tickSub ??= _webSocket.tickStream.listen(_onTick);
    _stateSub ??= _webSocket.stateStream.listen(_onState);
    if (!_webSocket.isConnected) {
      try {
        await _webSocket.connect();
      } catch (e) {
        _isRunning = false;
        _statusMessage = 'WS connection failed: $e — tap to retry';
        notifyListeners();
        return;
      }
    }
    if (!_webSocket.isConnected) {
      _isRunning = false;
      _statusMessage =
          'WS not connected (${_webSocket.connectionState.name}) — tap to retry';
      notifyListeners();
      return;
    }
    try {
      await _webSocket.subscribe(_settingsProvider.selectedPairs);
    } catch (_) {}
    await _news.start();
    await _settingsProvider.setAnalysisRunning(true);

    notifyListeners();
    await _runAnalysis();
    _timer = Timer.periodic(
      Duration(seconds: AppConfig.analysisIntervalSeconds),
      (_) => _runAnalysis(),
    );
  }

  Future<void> stopAnalysis() async {
    _isRunning = false;
    _timer?.cancel();
    _statusMessage = 'Stopped';
    _news.stop();
    await _webSocket.disconnect();
    await _settingsProvider.setAnalysisRunning(false);
    notifyListeners();
  }

  void _onSettingsChanged() {
    if (_isRunning && _webSocket.isConnected) {
      _webSocket.subscribe(_settingsProvider.selectedPairs);
    }
  }

  void _onTick(Tick t) {
    _currentPrices[t.symbol] = t.mid > 0 ? t.mid : t.last;
    _ticks[t.symbol] = t;
    final now = DateTime.now();
    if (now.difference(_lastTickNotify).inMilliseconds >= 1000) {
      _lastTickNotify = now;
      notifyListeners();
    }
  }

  void _onState(WsConnectionState state) {
    if (state == WsConnectionState.connected) {
      _webSocket.subscribe(_settingsProvider.selectedPairs);
    }
    notifyListeners();
  }

  // ============================ ANALYSIS LOOP ============================

  Future<void> _runAnalysis() async {
    if (_isAnalyzing) return;
    if (!_webSocket.isConnected) {
      _statusMessage =
          'WS ${_webSocket.connectionState.name} — waiting for connection…';
      notifyListeners();
      return;
    }
    _isAnalyzing = true;
    notifyListeners();

    final pairs = _settingsProvider.selectedPairs;
    for (final pair in pairs) {
      try {
        await _analyzePair(pair);
      } catch (e) {
        _pairStatuses[pair] = 'Error: $e';
        _statusMessage = 'Error analyzing $pair: $e';
      }
      notifyListeners();
    }

    _isAnalyzing = false;
    _statusMessage = _isRunning ? 'Analysis cycle complete' : 'Stopped';
    notifyListeners();
  }

  Future<void> _analyzePair(String pair) async {
    final state = _states.putIfAbsent(pair, () => _PairState());

    final candles1m = await _api.fetchOhlc(
      pair,
      Timeframe.m1,
      limit: AppConfig.swingLookback1m,
    );
    if (candles1m.isNotEmpty) {
      _currentPrices[pair] = candles1m.last.close;
    }

    switch (state.phase) {
      case AnalysisPhase.scanning:
        final c15 = await _api.fetchOhlc(
          pair,
          Timeframe.m15,
          limit: AppConfig.swingLookback15m + 20,
        );
        final c1d = await _api.fetchOhlc(pair, Timeframe.d1, limit: 60);
        await _phaseScanning(pair, state, c15, c1d);
      case AnalysisPhase.awaitingChoch:
        final c5 = await _api.fetchOhlc(
          pair,
          Timeframe.m5,
          limit: AppConfig.swingLookback5m + 20,
        );
        await _phaseAwaitingChoch(pair, state, c5);
      case AnalysisPhase.awaitingEntry:
        final c5 = await _api.fetchOhlc(
          pair,
          Timeframe.m5,
          limit: AppConfig.swingLookback5m + 20,
        );
        await _phaseAwaitingEntry(pair, state, c5, candles1m);
      case AnalysisPhase.monitoring:
        final c5 = await _api.fetchOhlc(
          pair,
          Timeframe.m5,
          limit: AppConfig.swingLookback5m + 20,
        );
        await _phaseMonitoring(pair, state, c5, candles1m);
    }

    _pairStatuses[pair] = state.detail;
  }

  // ============================ PHASE 1: SCANNING ============================

  Future<void> _phaseScanning(
    String pair,
    _PairState state,
    List<Candle> c15,
    List<Candle> c1d,
  ) async {
    final ctx = SweepReversalModel.detectSweepTap(
      symbol: pair,
      candles15m: c15,
      candles1d: c1d,
    );
    if (ctx == null) {
      state.detail = 'Scanning…';
      return;
    }

    final side = ctx.isLong ? 'sell-side' : 'buy-side';
    final signal = TradeSignal(
      pair: pair,
      type: ctx.direction,
      status: SignalStatus.sweep,
      poolType: ctx.sweptPool.type,
      sweepLevel: ctx.sweptPool.level,
      sweepExtreme: ctx.sweepExtreme,
      poiType: ctx.poi.type,
      poiTop: ctx.poi.top,
      poiBottom: ctx.poi.bottom,
      entry: ctx.sweepExtreme,
      stopLoss: 0,
      takeProfit1: 0,
      takeProfit2: 0,
      risk: 0,
      rrr1: 0,
      rrr2: 0,
      reason: 'Phase 1: $side ${ctx.sweptPool.type} swept @ '
          '${_fmt(ctx.sweptPool.level)} → 15m ${ctx.poi.type} tap @ '
          '${_fmt(ctx.isLong ? ctx.poi.top : ctx.poi.bottom)}',
    );

    final added = await _signalProvider.addSignal(signal);
    if (added) {
      state.signalId = signal.id;
    } else {
      final existing = _findOpenSetup(pair, ctx.direction);
      state.signalId = existing?.id;
    }

    state.ctx = ctx;
    state.phase = AnalysisPhase.awaitingChoch;
    state.detail = 'Sweep ${ctx.sweptPool.type} → awaiting CHoCH';
  }

  TradeSignal? _findOpenSetup(String pair, SignalType type) {
    for (final s in _signalProvider.activeSignals) {
      if (s.pair == pair && s.type == type) return s;
    }
    return null;
  }

  // ============================ PHASE 2: AWAITING CHoCH ============================

  Future<void> _phaseAwaitingChoch(
    String pair,
    _PairState state,
    List<Candle> c5,
  ) async {
    final ctx = state.ctx;
    final signal =
        state.signalId == null ? null : _signalProvider.byId(state.signalId!);
    if (ctx == null || signal == null) {
      _resetState(state, 'Scanning…');
      return;
    }

    if (SweepReversalModel.checkExtremeReset(
      ctx: ctx,
      candles5m: c5,
      symbol: pair,
    )) {
      await _cancelSetup(state, signal, 'New extreme during CHoCH wait');
      return;
    }

    final choch = SweepReversalModel.detectChoch(ctx: ctx, candles5m: c5);
    if (choch == null) {
      state.detail = 'Awaiting 5m CHoCH…';
      return;
    }

    state.choch = choch;
    state.phase = AnalysisPhase.awaitingEntry;
    state.detail = 'CHoCH @ ${_fmt(choch.referenceLevel)} '
        '(${choch.displacementType})';

    await _signalProvider.updateSignal(
      signal.copyWith(
        status: SignalStatus.choch,
        chochLevel: choch.referenceLevel,
        chochDisplacementAtr: choch.displacementAtr,
      ),
    );
  }

  // ============================ PHASE 3: AWAITING ENTRY ============================

  Future<void> _phaseAwaitingEntry(
    String pair,
    _PairState state,
    List<Candle> c5,
    List<Candle> c1,
  ) async {
    final ctx = state.ctx;
    final choch = state.choch;
    final signal =
        state.signalId == null ? null : _signalProvider.byId(state.signalId!);
    if (ctx == null || choch == null || signal == null) {
      _resetState(state, 'Scanning…');
      return;
    }

    if (SweepReversalModel.checkExtremeReset(
      ctx: ctx,
      candles5m: c5,
      symbol: pair,
    )) {
      await _cancelSetup(state, signal, 'New extreme before entry');
      return;
    }

    final plan = SweepReversalModel.buildEntryPlan(
      ctx: ctx,
      choch: choch,
      candles1m: c1,
      symbol: pair,
    );
    if (plan == null) {
      state.detail = 'Awaiting 1m ${ctx.isLong ? 'bullish' : 'bearish'} zone…';
      return;
    }

    final tick = _ticks[pair];
    final gate = SweepReversalModel.evaluateEntryGate(
      plan: plan,
      chochTime: choch.candleTime,
      candles1m: c1,
      tick: tick,
      highImpactEvents: _news.cachedEvents,
      now: DateTime.now().toUtc(),
    );

    if (!gate.allowed) {
      state.detail = gate.reason;
      if (gate.reason.startsWith('Filter 1')) {
        await _expireSetup(state, signal, gate.reason);
      }
      return;
    }

    final entrySignal = _applyEntryPlan(signal, plan, tick);
    await _signalProvider.updateSignal(entrySignal);

    state.phase = AnalysisPhase.monitoring;
    state.fillIndex = c1.length - 1;
    state.detail = 'LIMIT ${plan.zoneType} @ ${_fmt(plan.entry)}';

    await _notifications.showEntrySignal(
      pair: pair,
      direction: entrySignal.isBuy ? 'BUY' : 'SELL',
      entry: plan.entry,
      stopLoss: plan.stopLoss,
      takeProfit1: plan.takeProfit1,
      takeProfit2: plan.takeProfit2 ?? 0,
      rrr1: plan.rrr1,
      rrr2: plan.rrr2,
    );
  }

  TradeSignal _applyEntryPlan(TradeSignal s, EntryPlan plan, Tick? tick) {
    return s.copyWith(
      status: SignalStatus.entry,
      entryZoneType: plan.zoneType,
      entryZoneTop: plan.zoneTop,
      entryZoneBottom: plan.zoneBottom,
      entry: plan.entry,
      stopLoss: plan.stopLoss,
      takeProfit1: plan.takeProfit1,
      takeProfit2: plan.takeProfit2,
      risk: plan.risk,
      rrr1: plan.rrr1,
      rrr2: plan.rrr2,
      spreadAtSignal: tick?.spread ?? 0,
      reason: 'Limit ${plan.zoneType} @ ${_fmt(plan.entry)} | '
          'SL ${_fmt(plan.stopLoss)} | TP1 ${_fmt(plan.takeProfit1)}'
          '${plan.takeProfit2 != null ? ' | TP2 ${_fmt(plan.takeProfit2!)}' : ''}',
    );
  }

  // ============================ MONITORING ============================

  Future<void> _phaseMonitoring(
    String pair,
    _PairState state,
    List<Candle> c5,
    List<Candle> c1,
  ) async {
    final signal =
        state.signalId == null ? null : _signalProvider.byId(state.signalId!);
    if (signal == null || !signal.isOpen) {
      _resetState(state, 'Scanning…');
      return;
    }

    if (signal.status == SignalStatus.filled) {
      final closed = await _performance.monitorTrades(c1, pair);
      if (closed.isNotEmpty) {
        for (final result in closed) {
          if (result.signalId == signal.id) {
            await _applyOutcome(signal, result);
          }
        }
        _resetState(state, 'Scanning…');
      } else {
        state.detail = 'In trade — SL ${_fmt(signal.stopLoss)} / '
            'TP1 ${_fmt(signal.takeProfit1)}';
      }
      return;
    }

    final ctx = state.ctx;
    if (ctx != null &&
        SweepReversalModel.checkExtremeReset(
          ctx: ctx,
          candles5m: c5,
          symbol: pair,
        )) {
      await _cancelSetup(state, signal, 'New extreme before fill');
      return;
    }

    final choch = state.choch;
    if (choch != null) {
      final after =
          c1.where((c) => !c.openTime.isBefore(choch.candleTime)).length;
      if (after > AppConfig.retracementCandleLimit) {
        await _expireSetup(
          state,
          signal,
          'Limit not filled within ${AppConfig.retracementCandleLimit} 1m candles',
        );
        return;
      }
    }

    final fillIdx = TradeMonitor.findFillIndex(
      candles: c1,
      entry: signal.entry,
      isBullish: signal.isBuy,
      fillIndex: state.fillIndex,
    );
    if (fillIdx == -1) {
      state.detail = 'LIMIT ${_fmt(signal.entry)} — awaiting fill';
      return;
    }

    final filled = signal.copyWith(
      status: SignalStatus.filled,
      filledTime: DateTime.now().toUtc(),
      filledPrice: signal.entry,
      reason: 'Filled @ ${_fmt(signal.entry)}',
    );
    await _signalProvider.updateSignal(filled);

    state.fillIndex = fillIdx;
    _performance.registerFill(signal.id, fillIdx);
    await _performance.openResultForSignal(filled);
    await _notifications.showFill(
      pair: pair,
      direction: filled.isBuy ? 'BUY' : 'SELL',
      entry: signal.entry,
    );
    state.detail = 'FILLED @ ${_fmt(signal.entry)}';
  }

  Future<void> _applyOutcome(TradeSignal signal, TradeResult result) async {
    SignalStatus status;
    String outcome;
    switch (result.outcome) {
      case TradeOutcome.sl_hit:
        status = SignalStatus.sl_hit;
        outcome = 'SL HIT';
      case TradeOutcome.tp1_hit:
        status = SignalStatus.tp1_hit;
        outcome = 'TP1 HIT';
      case TradeOutcome.tp2_hit:
        status = SignalStatus.tp2_hit;
        outcome = 'TP2 HIT';
      case TradeOutcome.open:
        return;
    }

    final updated = signal.copyWith(
      status: status,
      exitTime: result.exitTimeMs != null
          ? DateTime.fromMillisecondsSinceEpoch(result.exitTimeMs!.round())
          : null,
      exitPrice: result.exitPrice,
      reason: '$outcome @ ${_fmt(result.exitPrice ?? 0)}',
    );
    await _signalProvider.updateSignal(updated);
    await _notifications.showTradeOutcome(
      pair: signal.pair,
      outcome: outcome,
      exitPrice: result.exitPrice ?? 0,
    );
  }

  // ============================ HELPERS ============================

  Future<void> _cancelSetup(_PairState state, TradeSignal signal, String reason) async {
    await _signalProvider.updateSignal(
      signal.copyWith(status: SignalStatus.cancelled, reason: reason),
    );
    _resetState(state, 'Scanning…');
  }

  Future<void> _expireSetup(_PairState state, TradeSignal signal, String reason) async {
    await _signalProvider.updateSignal(
      signal.copyWith(status: SignalStatus.expired, reason: reason),
    );
    _resetState(state, 'Scanning…');
  }

  void _resetState(_PairState state, String detail) {
    state.phase = AnalysisPhase.scanning;
    state.ctx = null;
    state.choch = null;
    state.signalId = null;
    state.fillIndex = -1;
    state.detail = detail;
  }

  static String _fmt(double v) => v.toStringAsFixed(5);

  @override
  void dispose() {
    _timer?.cancel();
    _tickSub?.cancel();
    _stateSub?.cancel();
    _settingsProvider.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
