import '../config/app_config.dart';
import '../models/candle.dart';
import '../models/trade_result.dart';
import '../models/trade_signal.dart';

class TradeMonitor {
  /// Index of the first candle after [fillIndex] that traded through [entry]
  /// in the direction of [isBullish] (limit fill), or -1 if not filled yet.
  static int findFillIndex({
    required List<Candle> candles,
    required double entry,
    required bool isBullish,
    required int fillIndex,
  }) {
    if (fillIndex >= candles.length - 1) return -1;
    for (int i = fillIndex + 1; i < candles.length; i++) {
      if (isBullish && candles[i].high >= entry) return i;
      if (!isBullish && candles[i].low <= entry) return i;
    }
    return -1;
  }

  /// Returns true if any candle after [fillIndex] traded through [entry]
  /// in the direction of [isBullish] (limit fill).
  static bool checkFill({
    required List<Candle> candles,
    required double entry,
    required bool isBullish,
    required int fillIndex,
  }) {
    return findFillIndex(
          candles: candles,
          entry: entry,
          isBullish: isBullish,
          fillIndex: fillIndex,
        ) !=
        -1;
  }

  /// Simulates the full trade path and returns the final outcome.
  /// TP1 hit -> partial close + SL moved to breakeven (entry).
  /// After TP1, a return to entry stops the remainder at breakeven.
  static TradeOutcome checkOutcome({
    required List<Candle> candles,
    required double entry,
    required double sl,
    required double tp1,
    required double tp2,
    required bool isBullish,
    required int fillIndex,
  }) {
    if (fillIndex >= candles.length - 1) return TradeOutcome.open;

    bool tp1Hit = false;
    for (int i = fillIndex + 1; i < candles.length; i++) {
      final c = candles[i];
      if (tp1Hit) {
        // SL already at breakeven (entry)
        final beHit = isBullish ? c.low <= entry : c.high >= entry;
        final tp2Hit = tp2 > 0 ? (isBullish ? c.high >= tp2 : c.low <= tp2) : false;
        if (beHit) return TradeOutcome.tp1_hit;
        if (tp2Hit) return TradeOutcome.tp2_hit;
      } else {
        final slHit = isBullish ? c.low <= sl : c.high >= sl;
        final tp1HitNow = isBullish ? c.high >= tp1 : c.low <= tp1;
        if (slHit) return TradeOutcome.sl_hit;
        if (tp1HitNow) tp1Hit = true;
      }
    }
    if (tp1Hit) return TradeOutcome.tp1_hit;
    return TradeOutcome.open;
  }

  static double realizedReturnFor({
    required TradeSignal signal,
    required TradeOutcome outcome,
  }) {
    final risk = signal.risk;
    final r1 = signal.reward1;
    final r2 = signal.reward2;
    final partial = AppConfig.partialClosePercent;
    switch (outcome) {
      case TradeOutcome.sl_hit:
        return risk;
      case TradeOutcome.tp1_hit:
        // Partial closed at TP1, remainder stopped at breakeven.
        return r1 * partial;
      case TradeOutcome.tp2_hit:
        return r1 * partial + r2 * (1 - partial);
      case TradeOutcome.open:
        return 0;
    }
  }
}
