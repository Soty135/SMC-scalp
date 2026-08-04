import '../models/candle.dart';

class FairValueGapResult {
  final int? index;
  final double? gapTop;
  final double? gapBottom;
  final bool isBullish;
  final bool isMitigated;

  bool get isValid => index != null;

  const FairValueGapResult({
    this.index,
    this.gapTop,
    this.gapBottom,
    this.isBullish = false,
    this.isMitigated = false,
  });
}

class FairValueGap {
  static List<FairValueGapResult> findAll(List<Candle> candles, {int lookback = 300}) {
    final gaps = <FairValueGapResult>[];
    final start = candles.length > lookback ? candles.length - lookback : 0;

    for (int i = start + 1; i < candles.length - 1; i++) {
      final prev = candles[i - 1];
      final curr = candles[i];
      final next = candles[i + 1];

      final bullishGap = curr.low > prev.high && next.low > curr.high;
      final bearishGap = curr.high < prev.low && next.high < curr.low;

      if (bullishGap) {
        gaps.add(FairValueGapResult(
          index: i,
          gapTop: curr.low,
          gapBottom: prev.high,
          isBullish: true,
          isMitigated: _isGapMitigated(candles, i, curr.low, prev.high, true),
        ));
      }
      if (bearishGap) {
        gaps.add(FairValueGapResult(
          index: i,
          gapTop: prev.low,
          gapBottom: curr.high,
          isBullish: false,
          isMitigated: _isGapMitigated(candles, i, prev.low, curr.high, false),
        ));
      }
    }
    return gaps;
  }

  static bool _isGapMitigated(
    List<Candle> candles, int gapIndex, double gapTop, double gapBottom, bool isBullish,
  ) {
    for (int i = gapIndex + 1; i < candles.length; i++) {
      if (isBullish && candles[i].low <= gapTop) return true;
      if (!isBullish && candles[i].high >= gapBottom) return true;
    }
    return false;
  }
}
