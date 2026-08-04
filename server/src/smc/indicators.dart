import '../models/candle.dart';

class Indicators {
  static List<double> calculateAtr(List<Candle> candles, int period) {
    final n = candles.length;
    if (n < period + 1) {
      return List.filled(n, 0);
    }

    final tr = <double>[];
    for (int i = 1; i < n; i++) {
      final highLow = candles[i].high - candles[i].low;
      final highClose = (candles[i].high - candles[i - 1].close).abs();
      final lowClose = (candles[i].low - candles[i - 1].close).abs();
      tr.add([highLow, highClose, lowClose].reduce((a, b) => a > b ? a : b));
    }

    final atrSmooth = <double>[];
    final firstMean = tr.take(period).reduce((a, b) => a + b) / period;
    atrSmooth.add(firstMean);

    for (int i = period; i < tr.length; i++) {
      atrSmooth.add((atrSmooth.last * (period - 1) + tr[i]) / period);
    }

    final result = List.filled(n, 0.0);
    for (int i = period; i < n; i++) {
      result[i] = atrSmooth[i - period];
    }
    return result;
  }

  static bool isDisplacementCandle(
    Candle candle,
    double atrValue,
    double multiplier,
  ) {
    return atrValue > 0 && candle.body > atrValue * multiplier;
  }
}
