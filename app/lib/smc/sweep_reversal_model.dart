import 'dart:math';
import '../config/app_config.dart';
import '../models/candle.dart';
import '../models/tick.dart';
import '../models/trade_signal.dart';
import 'fair_value_gap.dart';
import 'indicators.dart';
import 'liquidity.dart';
import 'market_structure.dart';
import 'order_block.dart';
import '../services/news_service.dart';

/// A 15m Point of Interest (Order Block or Fair Value Gap).
class PoI {
  final String type; // 'OB' | 'FVG'
  final bool isBullish; // bullish = demand, bearish = supply
  final double top;
  final double bottom;
  final int index;

  const PoI({
    required this.type,
    required this.isBullish,
    required this.top,
    required this.bottom,
    required this.index,
  });
}

/// Phase 1 output: a swept liquidity pool + a tapped 15m POI.
class SweepContext {
  final SignalType direction;
  final LiquidityPool sweptPool;
  final double sweepExtreme;
  final DateTime sweepTime;
  final PoI poi;
  final List<LiquidityPool> pools;
  final List<PoI> pois;

  bool get isLong => direction == SignalType.buy;

  const SweepContext({
    required this.direction,
    required this.sweptPool,
    required this.sweepExtreme,
    required this.sweepTime,
    required this.poi,
    required this.pools,
    required this.pois,
  });
}

/// Phase 2 output: confirmed CHoCH with displacement.
class ChochResult {
  final bool confirmed;
  final double referenceLevel;
  final int candleIndex;
  final DateTime candleTime;
  final double displacementAtr;
  final String displacementType; // 'candle' | 'impulse'

  const ChochResult({
    required this.confirmed,
    required this.referenceLevel,
    required this.candleIndex,
    required this.candleTime,
    required this.displacementAtr,
    required this.displacementType,
  });
}

/// Phase 3 output: entry plan (limit at proximal edge + risk layout).
class EntryPlan {
  final String zoneType; // 'bullish FVG' | 'bearish FVG' | 'bullish OB' | 'bearish OB'
  final double zoneTop;
  final double zoneBottom;
  final double entry; // proximal edge (limit)
  final double stopLoss;
  final double takeProfit1;
  final double? takeProfit2;
  final double risk;
  final double rrr1;
  final double rrr2;

  bool get isLong => entry <= zoneTop;

  const EntryPlan({
    required this.zoneType,
    required this.zoneTop,
    required this.zoneBottom,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit1,
    this.takeProfit2,
    required this.risk,
    required this.rrr1,
    required this.rrr2,
  });
}

class SweepReversalModel {
  // ============================ PHASE 1 ============================

  static SweepContext? detectSweepTap({
    required String symbol,
    required List<Candle> candles15m,
    required List<Candle> candles1d,
  }) {
    if (candles15m.length < 30) return null;

    final pip = AppConfig.pipValue(symbol);
    final atrList = Indicators.calculateAtr(candles15m, AppConfig.atrPeriod);
    final atr = atrList.isNotEmpty ? atrList.last : pip;
    final buffer = _sweepBuffer(symbol, pip, atr);

    final pools = Liquidity.findPools(
      candles15m: candles15m,
      candles1d: candles1d,
      atr: atr,
      pip: pip,
    );
    final pois = _collectPois(candles15m);
    if (pools.isEmpty || pois.isEmpty) return null;

    final start = candles15m.length - AppConfig.sweepLookbackBars;
    if (start < 0) return null;

    for (int i = start; i < candles15m.length; i++) {
      final c = candles15m[i];

      // Sell-side pool swept (below) -> potential LONG
      for (final pool in pools) {
        if (pool.side == PoolSide.sellSide && c.low <= pool.level - buffer) {
          final ctx = _tryPoiTap(
            candles15m: candles15m,
            pois: pois,
            pools: pools,
            i: i,
            isLong: true,
            sweptPool: pool,
            buffer: buffer,
          );
          if (ctx != null) return ctx;
        }
      }
      // Buy-side pool swept (above) -> potential SHORT
      for (final pool in pools) {
        if (pool.side == PoolSide.buySide && c.high >= pool.level + buffer) {
          final ctx = _tryPoiTap(
            candles15m: candles15m,
            pois: pois,
            pools: pools,
            i: i,
            isLong: false,
            sweptPool: pool,
            buffer: buffer,
          );
          if (ctx != null) return ctx;
        }
      }
    }
    return null;
  }

  static SweepContext? _tryPoiTap({
    required List<Candle> candles15m,
    required List<PoI> pois,
    required List<LiquidityPool> pools,
    required int i,
    required bool isLong,
    required LiquidityPool sweptPool,
    required double buffer,
  }) {
    final start = candles15m.length - AppConfig.sweepLookbackBars;
    final extreme = isLong
        ? _minLow(candles15m, start, i)
        : _maxHigh(candles15m, start, i);

    // Sweep candle (or immediate next candle) must tap an unmitigated POI
    // of the reversal polarity.
    for (final poi in pois) {
      if (poi.isBullish != isLong) continue;
      final candleRangeLow = min(candles15m[i].low, candles15m[i + 1 >= candles15m.length ? i : i + 1].low);
      final candleRangeHigh = max(candles15m[i].high, candles15m[i + 1 >= candles15m.length ? i : i + 1].high);
      final overlaps = candleRangeLow <= poi.top && candleRangeHigh >= poi.bottom;
      if (!overlaps) continue;

      // Prefer the POI nearest to the sweep extreme.
      final extremeIdx = _extremeIndex(candles15m, start, i, isLong);
      return SweepContext(
        direction: isLong ? SignalType.buy : SignalType.sell,
        sweptPool: sweptPool,
        sweepExtreme: extreme,
        sweepTime: candles15m[extremeIdx].openTime,
        poi: poi,
        pools: pools,
        pois: pois,
      );
    }
    return null;
  }

  static List<PoI> _collectPois(List<Candle> candles) {
    final struct = MarketStructure.analyze(candles, lookback: AppConfig.poiLookback15m);
    final pois = <PoI>[];

    for (final ob in OrderBlock.collectUnmitigated(
      candles,
      swingHighs: struct.swingHighIndices,
      swingLows: struct.swingLowIndices,
      lookback: AppConfig.poiLookback15m,
    )) {
      pois.add(PoI(type: 'OB', isBullish: ob.isBullish, top: ob.top!, bottom: ob.bottom!, index: ob.index!));
    }
    for (final f in FairValueGap.findAll(candles, lookback: AppConfig.poiLookback15m)) {
      if (!f.isMitigated) {
        pois.add(PoI(type: 'FVG', isBullish: f.isBullish, top: f.gapTop!, bottom: f.gapBottom!, index: f.index!));
      }
    }
    return pois;
  }

  // ============================ PHASE 2 ============================

  static ChochResult? detectChoch({
    required SweepContext ctx,
    required List<Candle> candles5m,
  }) {
    if (candles5m.length < 30) return null;

    final struct = MarketStructure.analyze(candles5m, lookback: AppConfig.swingLookback5m);
    final atrList = Indicators.calculateAtr(candles5m, AppConfig.atrPeriod);
    final isLong = ctx.isLong;

    for (int i = 0; i < candles5m.length; i++) {
      if (!candles5m[i].openTime.isAfter(ctx.sweepTime)) continue;

      // Reference swing accounts for structure built during the sweep phase:
      // freshest swing high/low above the swept extreme up to this candle.
      final ref = isLong
          ? MarketStructure.mostRecentSwingAbove(candles5m, struct.swingHighIndices, ctx.sweepExtreme, upToIndex: i)
          : MarketStructure.mostRecentSwingBelow(candles5m, struct.swingLowIndices, ctx.sweepExtreme, upToIndex: i);
      if (ref == null) continue;

      final confirmed = isLong ? candles5m[i].close > ref : candles5m[i].close < ref;
      if (!confirmed) continue;

      final atr = atrList[i];
      final candleDisp = Indicators.isDisplacementCandle(
        candles5m[i], atr, AppConfig.displacementAtrMultiplier,
      );
      final runDisp = _impulseDisplacement(candles5m, i, ref, atr, isLong);

      if (candleDisp || runDisp) {
        return ChochResult(
          confirmed: true,
          referenceLevel: ref,
          candleIndex: i,
          candleTime: candles5m[i].openTime,
          displacementAtr: atr,
          displacementType: candleDisp ? 'candle' : 'impulse',
        );
      }
    }
    return null;
  }

  static bool _impulseDisplacement(
    List<Candle> candles, int chochIdx, double ref, double atr, bool isLong,
  ) {
    if (atr <= 0) return false;
    double extreme = candles[chochIdx].low;
    for (int j = chochIdx; j >= 0; j--) {
      if (isLong) {
        if (candles[j].low < extreme) extreme = candles[j].low;
        if (candles[j].high <= ref) break;
      } else {
        if (candles[j].high > extreme) extreme = candles[j].high;
        if (candles[j].low >= ref) break;
      }
    }
    final dist = isLong ? candles[chochIdx].close - extreme : extreme - candles[chochIdx].close;
    return dist >= atr * AppConfig.displacementAtrMultiplier;
  }

  // ============================ PHASE 3 ============================

  static EntryPlan? buildEntryPlan({
    required SweepContext ctx,
    required ChochResult choch,
    required List<Candle> candles1m,
    required String symbol,
  }) {
    if (candles1m.length < 30) return null;

    final pip = AppConfig.pipValue(symbol);
    final atrList = Indicators.calculateAtr(candles1m, AppConfig.atrPeriod);
    final atr = atrList.isNotEmpty ? atrList.last : pip;
    final isLong = ctx.isLong;

    final leg = candles1m.where((c) =>
        !c.openTime.isBefore(ctx.sweepTime) &&
        !c.openTime.isAfter(choch.candleTime.add(const Duration(minutes: 1)))).toList();
    if (leg.length < 3) return null;

    final fvgs = FairValueGap.findAll(leg);
    final relevant = fvgs.where((f) => f.isBullish == isLong && !f.isMitigated).toList();

    double? zoneTop;
    double? zoneBottom;
    String zoneType = '';

    if (relevant.length == 1) {
      zoneTop = relevant.first.gapTop;
      zoneBottom = relevant.first.gapBottom;
      zoneType = isLong ? 'bullish FVG' : 'bearish FVG';
    } else if (relevant.length > 1) {
      // Adjustment 1: deepest FVG (closest to sweep extreme).
      final chosen = isLong
          ? relevant.reduce((a, b) => a.gapTop! < b.gapTop! ? a : b)
          : relevant.reduce((a, b) => a.gapBottom! > b.gapBottom! ? a : b);
      zoneTop = chosen.gapTop;
      zoneBottom = chosen.gapBottom;
      zoneType = isLong ? 'bullish FVG' : 'bearish FVG';
    } else {
      final struct = MarketStructure.analyze(leg);
      final ob = isLong
          ? OrderBlock.findLastBullish(leg, swingLows: struct.swingLowIndices, lookback: leg.length)
          : OrderBlock.findLastBearish(leg, swingHighs: struct.swingHighIndices, lookback: leg.length);
      if (ob.isValid) {
        zoneTop = ob.top;
        zoneBottom = ob.bottom;
        zoneType = isLong ? 'bullish OB' : 'bearish OB';
      }
    }

    if (zoneTop == null || zoneBottom == null) return null;

    final entry = isLong ? zoneTop : zoneBottom; // proximal edge (limit)
    final slBuffer = _slBuffer(symbol, pip, atr);
    final sl = isLong ? ctx.sweepExtreme - slBuffer : ctx.sweepExtreme + slBuffer;
    final risk = (entry - sl).abs();
    if (risk <= 0) return null;

    final tp1 = isLong
        ? entry + AppConfig.minTp1Rrr * risk
        : entry - AppConfig.minTp1Rrr * risk;

    final tp2 = _findTp2(ctx, entry, isLong);
    final rrr2 = tp2 != null ? (tp2 - entry).abs() / risk : 0.0;

    return EntryPlan(
      zoneType: zoneType,
      zoneTop: zoneTop,
      zoneBottom: zoneBottom,
      entry: entry,
      stopLoss: sl,
      takeProfit1: tp1,
      takeProfit2: tp2,
      risk: risk,
      rrr1: AppConfig.minTp1Rrr,
      rrr2: rrr2,
    );
  }

  /// Nearest opposing liquidity pool or POI beyond the entry.
  static double? _findTp2(SweepContext ctx, double entry, bool isLong) {
    double? best;
    for (final pool in ctx.pools) {
      if (isLong && pool.side == PoolSide.buySide && pool.level > entry) {
        if (best == null || pool.level < best) best = pool.level;
      }
      if (!isLong && pool.side == PoolSide.sellSide && pool.level < entry) {
        if (best == null || pool.level > best) best = pool.level;
      }
    }
    for (final poi in ctx.pois) {
      if (isLong && !poi.isBullish && poi.top > entry) {
        if (best == null || poi.top < best) best = poi.top;
      }
      if (!isLong && poi.isBullish && poi.bottom < entry) {
        if (best == null || poi.bottom > best) best = poi.bottom;
      }
    }
    return best;
  }

  // ============================ FILTERS ============================

  static ({bool allowed, String reason}) evaluateEntryGate({
    required EntryPlan plan,
    required DateTime chochTime,
    required List<Candle> candles1m,
    required Tick? tick,
    required List<CalendarEvent> highImpactEvents,
    required DateTime now,
  }) {
    // Filter 1: 1m retracement must not exceed 20 candles after the 5m CHoCH.
    final afterChoch = candles1m.where((c) => !c.openTime.isBefore(chochTime)).length;
    if (afterChoch > AppConfig.retracementCandleLimit) {
      return (
        allowed: false,
        reason: 'Filter 1: retracement $afterChoch > ${AppConfig.retracementCandleLimit} candles after CHoCH',
      );
    }

    // Filter 2: spread must not exceed 15% of SL distance.
    if (tick != null && plan.risk > 0) {
      final limit = AppConfig.maxSpreadFractionOfSl * plan.risk;
      if (tick.spread > limit) {
        return (
          allowed: false,
          reason: 'Filter 2: spread ${tick.spread.toStringAsFixed(6)} > 15% of SL distance (${limit.toStringAsFixed(6)})',
        );
      }
    }

    // Filter 3: high-impact news within ±30 minutes.
    for (final e in highImpactEvents) {
      if (e.time.difference(now).inMinutes.abs() <= AppConfig.newsWindowMinutes) {
        return (
          allowed: false,
          reason: 'Filter 3: ${e.name} (${e.countryCode}) within ${AppConfig.newsWindowMinutes} min',
        );
      }
    }

    // Filter 4: R:R to TP2 must be >= 1:2.
    if (plan.rrr2 < AppConfig.minTp2Rrr) {
      return (
        allowed: false,
        reason: 'Filter 4: RRR to TP2 ${plan.rrr2.toStringAsFixed(2)} < ${AppConfig.minTp2Rrr}',
      );
    }

    return (allowed: true, reason: '');
  }

  // ============================ RESET (adjustment 3) ============================

  static bool checkExtremeReset({
    required SweepContext ctx,
    required List<Candle> candles5m,
    required String symbol,
  }) {
    final pip = AppConfig.pipValue(symbol);
    final atrList = Indicators.calculateAtr(candles5m, AppConfig.atrPeriod);
    final atr = atrList.isNotEmpty ? atrList.last : pip;
    final buffer = _sweepBuffer(symbol, pip, atr);

    for (final c in candles5m) {
      if (!c.openTime.isAfter(ctx.sweepTime)) continue;
      if (ctx.isLong && c.low < ctx.sweepExtreme - buffer) return true;
      if (!ctx.isLong && c.high > ctx.sweepExtreme + buffer) return true;
    }
    return false;
  }

  // ============================ HELPERS ============================

  static double _sweepBuffer(String symbol, double pip, double atr) {
    if (AppConfig.isMetal(symbol) || AppConfig.isCrypto(symbol)) {
      return max(atr * 0.1, pip);
    }
    return AppConfig.sweepBufferPips * pip;
  }

  static double _slBuffer(String symbol, double pip, double atr) {
    if (AppConfig.isMetal(symbol)) return atr * AppConfig.metalSlAtrMultiplier;
    if (AppConfig.isCrypto(symbol)) return atr * AppConfig.cryptoSlAtrMultiplier;
    return AppConfig.sweepSlMultiplier * pip;
  }

  static double _minLow(List<Candle> candles, int from, int to) {
    double m = candles[from].low;
    for (int k = from + 1; k <= to; k++) {
      if (candles[k].low < m) m = candles[k].low;
    }
    return m;
  }

  static double _maxHigh(List<Candle> candles, int from, int to) {
    double m = candles[from].high;
    for (int k = from + 1; k <= to; k++) {
      if (candles[k].high > m) m = candles[k].high;
    }
    return m;
  }

  static int _extremeIndex(List<Candle> candles, int from, int to, bool isLong) {
    int idx = from;
    for (int k = from + 1; k <= to; k++) {
      if (isLong && candles[k].low < candles[idx].low) idx = k;
      if (!isLong && candles[k].high > candles[idx].high) idx = k;
    }
    return idx;
  }
}
