import '../models/candle.dart';

class OrderBlockResult {
  final int? index;
  final double? top;
  final double? bottom;
  final bool isBullish;
  final bool isMitigated;

  bool get isValid => index != null;

  const OrderBlockResult({
    this.index,
    this.top,
    this.bottom,
    this.isBullish = false,
    this.isMitigated = false,
  });
}

class OrderBlock {
  static OrderBlockResult findLastBullish(
    List<Candle> candles, {
    List<int>? swingLows,
    int lookback = 100,
  }) {
    final start = candles.length > lookback ? candles.length - lookback : 0;
    for (int i = candles.length - 1; i >= start + 1; i--) {
      if (!candles[i].isBearish) continue;
      if (i + 1 >= candles.length) continue;
      if (swingLows != null && !swingLows.contains(i)) continue;
      if (!_isStrongMove(candles, i, isBullish: true)) continue;

      final obLow = candles[i].low;
      final obHigh = candles[i].high;
      return OrderBlockResult(
        index: i,
        top: obHigh,
        bottom: obLow,
        isBullish: true,
        isMitigated: _isObMitigated(candles, i, obLow, obHigh, true),
      );
    }
    return OrderBlockResult();
  }

  static OrderBlockResult findLastBearish(
    List<Candle> candles, {
    List<int>? swingHighs,
    int lookback = 100,
  }) {
    final start = candles.length > lookback ? candles.length - lookback : 0;
    for (int i = candles.length - 1; i >= start + 1; i--) {
      if (!candles[i].isBullish) continue;
      if (i + 1 >= candles.length) continue;
      if (swingHighs != null && !swingHighs.contains(i)) continue;
      if (!_isStrongMove(candles, i, isBullish: false)) continue;

      final obLow = candles[i].low;
      final obHigh = candles[i].high;
      return OrderBlockResult(
        index: i,
        top: obHigh,
        bottom: obLow,
        isBullish: false,
        isMitigated: _isObMitigated(candles, i, obLow, obHigh, false),
      );
    }
    return OrderBlockResult();
  }

  /// Collects every unmitigated order block in the lookback window, newest first.
  static List<OrderBlockResult> collectUnmitigated(
    List<Candle> candles, {
    List<int>? swingHighs,
    List<int>? swingLows,
    int lookback = 100,
  }) {
    final result = <OrderBlockResult>[];
    final start = candles.length > lookback ? candles.length - lookback : 0;

    for (int i = candles.length - 1; i >= start + 1; i--) {
      // Bullish OB: bearish candle at a swing low followed by strong bullish move
      if (candles[i].isBearish && i + 1 < candles.length &&
          (swingLows == null || swingLows.contains(i)) &&
          _isStrongMove(candles, i, isBullish: true)) {
        final obLow = candles[i].low;
        final obHigh = candles[i].high;
        if (!_isObMitigated(candles, i, obLow, obHigh, true)) {
          result.add(OrderBlockResult(
            index: i, top: obHigh, bottom: obLow, isBullish: true,
            isMitigated: false,
          ));
        }
      }
      // Bearish OB: bullish candle at a swing high followed by strong bearish move
      if (candles[i].isBullish && i + 1 < candles.length &&
          (swingHighs == null || swingHighs.contains(i)) &&
          _isStrongMove(candles, i, isBullish: false)) {
        final obLow = candles[i].low;
        final obHigh = candles[i].high;
        if (!_isObMitigated(candles, i, obLow, obHigh, false)) {
          result.add(OrderBlockResult(
            index: i, top: obHigh, bottom: obLow, isBullish: false,
            isMitigated: false,
          ));
        }
      }
    }
    return result;
  }

  static bool _isStrongMove(List<Candle> candles, int obIndex, {required bool isBullish}) {
    if (obIndex + 1 >= candles.length) return false;
    final moveCandle = candles[obIndex + 1];
    final avgBody = _averageBody(candles, obIndex);
    if (isBullish) {
      return moveCandle.isBullish && avgBody > 0 && moveCandle.body > avgBody * 1.5;
    }
    return moveCandle.isBearish && avgBody > 0 && moveCandle.body > avgBody * 1.5;
  }

  static bool _isObMitigated(
    List<Candle> candles, int obIndex, double obLow, double obHigh, bool isBullish,
  ) {
    for (int i = obIndex + 1; i < candles.length; i++) {
      if (isBullish && candles[i].low < obLow) return true;
      if (!isBullish && candles[i].high > obHigh) return true;
    }
    return false;
  }

  static double _averageBody(List<Candle> candles, int upTo) {
    int count = 0;
    double total = 0;
    final start = upTo > 20 ? upTo - 20 : 0;
    for (int i = start; i < upTo; i++) {
      total += candles[i].body;
      count++;
    }
    return count > 0 ? total / count : 0;
  }
}
