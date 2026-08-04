import '../config/app_config.dart';
import '../models/candle.dart';
import 'market_structure.dart';

enum PoolSide { buySide, sellSide }

class LiquidityPool {
  /// type: prior_day_high/low, session_high/low, eqh/eql, swing_high/low
  final String type;
  final double level;
  final PoolSide side;

  const LiquidityPool({
    required this.type,
    required this.level,
    required this.side,
  });

  @override
  String toString() => '$type@${level.toStringAsFixed(5)}';
}

class Liquidity {
  /// Builds all candidate liquidity pools from 15m + daily structure.
  static List<LiquidityPool> findPools({
    required List<Candle> candles15m,
    required List<Candle> candles1d,
    required double atr,
    required double pip,
  }) {
    final pools = <LiquidityPool>[];
    final struct = MarketStructure.analyze(candles15m, lookback: AppConfig.swingLookback15m);

    // 1) Prior day high / low
    if (candles1d.length >= 2) {
      final prev = candles1d[candles1d.length - 2];
      pools.add(LiquidityPool(type: 'prior_day_high', level: prev.high, side: PoolSide.buySide));
      pools.add(LiquidityPool(type: 'prior_day_low', level: prev.low, side: PoolSide.sellSide));
    }

    // 2) Prior session high / low
    final session = _priorSession(candles15m, DateTime.now().toUtc());
    if (session != null) {
      pools.add(LiquidityPool(type: 'session_high', level: session.$1, side: PoolSide.buySide));
      pools.add(LiquidityPool(type: 'session_low', level: session.$2, side: PoolSide.sellSide));
    }

    // 3) EQH / EQL clusters (ATR-scaled tolerance, all assets)
    final tolerance = (atr * AppConfig.eqToleranceAtrMultiplier).clamp(pip, double.infinity);
    final eqh = _clusterLevels(struct.swingHighIndices, candles15m, tolerance, isHigh: true);
    for (final lvl in eqh) {
      pools.add(LiquidityPool(type: 'eqh', level: lvl, side: PoolSide.buySide));
    }
    final eql = _clusterLevels(struct.swingLowIndices, candles15m, tolerance, isHigh: false);
    for (final lvl in eql) {
      pools.add(LiquidityPool(type: 'eql', level: lvl, side: PoolSide.sellSide));
    }

    // 4) Most recent swing high / low
    if (struct.lastSwingHigh != null) {
      pools.add(LiquidityPool(
        type: 'swing_high',
        level: struct.lastSwingHigh!,
        side: PoolSide.buySide,
      ));
    }
    if (struct.lastSwingLow != null) {
      pools.add(LiquidityPool(
        type: 'swing_low',
        level: struct.lastSwingLow!,
        side: PoolSide.sellSide,
      ));
    }

    return pools;
  }

  /// Most recently completed session's high/low computed from 15m candles,
  /// bucketed by the configured UTC hour windows.
  static (double, double)? _priorSession(List<Candle> candles, DateTime now) {
    if (candles.isEmpty) return null;

    final currentHour = now.hour;
    int priorWindow = -1;
    for (int w = 0; w < AppConfig.sessionWindowsUtc.length; w++) {
      final start = AppConfig.sessionWindowsUtc[w][0];
      final end = AppConfig.sessionWindowsUtc[w][1];
      if (currentHour >= start && currentHour < end) {
        priorWindow = (w - 1 + AppConfig.sessionWindowsUtc.length) % AppConfig.sessionWindowsUtc.length;
        break;
      }
    }
    if (priorWindow == -1) {
      priorWindow = AppConfig.sessionWindowsUtc.length - 1;
    }
    final sStart = AppConfig.sessionWindowsUtc[priorWindow][0];
    final sEnd = AppConfig.sessionWindowsUtc[priorWindow][1];

    double? high;
    double? low;
    for (final c in candles.reversed) {
      final h = c.openTime.hour;
      final inWindow = sStart < sEnd
          ? (h >= sStart && h < sEnd)
          : (h >= sStart || h < sEnd);
      if (inWindow) {
        if (high == null || c.high > high) high = c.high;
        if (low == null || c.low < low) low = c.low;
      }
    }
    if (high == null || low == null) return null;
    return (high, low);
  }

  /// Greedy clustering of swing values within [tolerance]. Returns cluster
  /// mean levels for clusters of size >= 2.
  static List<double> _clusterLevels(
    List<int> swingIndices,
    List<Candle> candles,
    double tolerance, {
    required bool isHigh,
  }) {
    final values = <double>[];
    for (final idx in swingIndices) {
      values.add(isHigh ? candles[idx].high : candles[idx].low);
    }
    values.sort();

    final clusters = <List<double>>[];
    for (final v in values) {
      var placed = false;
      for (final cluster in clusters) {
        final ref = isHigh ? cluster.reduce((a, b) => a > b ? a : b)
                           : cluster.reduce((a, b) => a < b ? a : b);
        if ((v - ref).abs() <= tolerance) {
          cluster.add(v);
          placed = true;
          break;
        }
      }
      if (!placed) clusters.add([v]);
    }

    return clusters
        .where((c) => c.length >= 2)
        .map((c) => c.reduce((a, b) => a + b) / c.length)
        .toList();
  }
}
