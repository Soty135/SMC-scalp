import '../models/candle.dart';

enum MarketTrend { uptrend, downtrend, ranging }

class MarketStructureResult {
  final MarketTrend trend;
  final List<int> swingHighIndices;
  final List<int> swingLowIndices;
  final double? lastSwingHigh;
  final double? lastSwingLow;
  final bool isBreakOfStructure;
  final bool isChangeOfCharacter;
  final bool isStrongTrend;
  final int? bosIndex;
  final int? chochIndex;

  const MarketStructureResult({
    this.trend = MarketTrend.ranging,
    this.swingHighIndices = const [],
    this.swingLowIndices = const [],
    this.lastSwingHigh,
    this.lastSwingLow,
    this.isBreakOfStructure = false,
    this.isChangeOfCharacter = false,
    this.isStrongTrend = false,
    this.bosIndex,
    this.chochIndex,
  });
}

class MarketStructure {
  static MarketStructureResult analyze(List<Candle> candles, {int lookback = 100}) {
    if (candles.length < 5) {
      return MarketStructureResult();
    }

    final swingHighs = <int>[];
    final swingLows = <int>[];
    final start = candles.length > lookback ? candles.length - lookback : 0;

    for (int i = start + 2; i < candles.length - 2; i++) {
      if (candles[i].high > candles[i - 1].high &&
          candles[i].high > candles[i - 2].high &&
          candles[i].high > candles[i + 1].high &&
          candles[i].high > candles[i + 2].high) {
        swingHighs.add(i);
      }
      if (candles[i].low < candles[i - 1].low &&
          candles[i].low < candles[i - 2].low &&
          candles[i].low < candles[i + 1].low &&
          candles[i].low < candles[i + 2].low) {
        swingLows.add(i);
      }
    }

    return MarketStructureResult(
      swingHighIndices: swingHighs,
      swingLowIndices: swingLows,
      lastSwingHigh: swingHighs.isNotEmpty ? candles[swingHighs.last].high : null,
      lastSwingLow: swingLows.isNotEmpty ? candles[swingLows.last].low : null,
    );
  }

  /// Most recent swing high (for LONG) / swing low (for SHORT) formed up to
  /// [upToIndex] that lies on the reversal side of [referencePrice]. For a
  /// LONG reversal this is the freshest swing high ABOVE the swept extreme —
  /// structure built during the sweep phase is included automatically because
  /// the scan runs all the way up to the current index.
  static double? mostRecentSwingAbove(List<Candle> candles, List<int> swingHighIndices,
      double referencePrice, {int? upToIndex}) {
    final upto = (upToIndex ?? candles.length - 1).clamp(0, candles.length - 1);
    int? best;
    for (final idx in swingHighIndices) {
      if (idx > upto) continue;
      if (candles[idx].high > referencePrice) {
        if (best == null || idx > best) best = idx;
      }
    }
    return best == null ? null : candles[best].high;
  }

  static double? mostRecentSwingBelow(List<Candle> candles, List<int> swingLowIndices,
      double referencePrice, {int? upToIndex}) {
    final upto = (upToIndex ?? candles.length - 1).clamp(0, candles.length - 1);
    int? best;
    for (final idx in swingLowIndices) {
      if (idx > upto) continue;
      if (candles[idx].low < referencePrice) {
        if (best == null || idx > best) best = idx;
      }
    }
    return best == null ? null : candles[best].low;
  }
}
