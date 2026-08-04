import 'package:flutter_test/flutter_test.dart';

import 'package:smc_scalp_app/models/candle.dart';
import 'package:smc_scalp_app/models/trade_result.dart';
import 'package:smc_scalp_app/models/trade_signal.dart';
import 'package:smc_scalp_app/smc/trade_monitor.dart';

List<Candle> _candles(DateTime t0, List<List<double>> rows) => [
      for (int i = 0; i < rows.length; i++)
        Candle(
          openTime: t0.add(Duration(minutes: i)),
          open: rows[i][0],
          high: rows[i][1],
          low: rows[i][2],
          close: rows[i][3],
        ),
    ];

TradeSignal _signal({double risk = 100}) => TradeSignal(
      pair: 'EURUSD',
      type: SignalType.buy,
      sweepExtreme: 1.0949,
      entry: 1000,
      stopLoss: 900,
      takeProfit1: 1200,
      takeProfit2: 1300,
      risk: risk,
      rrr1: 2.0,
      rrr2: 3.0,
    );

void main() {
  group('findFillIndex / checkFill', () {
    final t0 = DateTime.utc(2026, 1, 2, 8, 0);

    test('returns the first candle that trades through a long limit', () {
      final candles = _candles(t0, [
        [1.0980, 1.0985, 1.0978, 1.0982],
        [1.0982, 1.0995, 1.0980, 1.0990],
        [1.0990, 1.1005, 1.0988, 1.1000],
      ]);
      expect(
        TradeMonitor.findFillIndex(candles: candles, entry: 1.1000, isBullish: true, fillIndex: 0),
        2,
      );
      expect(
        TradeMonitor.checkFill(candles: candles, entry: 1.1000, isBullish: true, fillIndex: 0),
        isTrue,
      );
    });

    test('returns -1 when the limit is never traded through', () {
      final candles = _candles(t0, [
        [1.0980, 1.0985, 1.0978, 1.0982],
        [1.0982, 1.0988, 1.0980, 1.0985],
      ]);
      expect(
        TradeMonitor.findFillIndex(candles: candles, entry: 1.1000, isBullish: true, fillIndex: 0),
        -1,
      );
    });
  });

  group('checkOutcome', () {
    final t0 = DateTime.utc(2026, 1, 2, 8, 0);
    // entry 1.1000, sl 1.0985, tp1 1.1020, tp2 1.1060
    const entry = 1.1000;
    const sl = 1.0985;
    const tp1 = 1.1020;
    const tp2 = 1.1060;

    test('returns sl_hit when SL is hit before TP1', () {
      final candles = _candles(t0, [
        [1.1000, 1.1002, 1.0998, 1.1000],
        [1.1000, 1.1002, 1.0980, 1.0985],
      ]);
      expect(
        TradeMonitor.checkOutcome(candles: candles, entry: entry, sl: sl, tp1: tp1, tp2: tp2, isBullish: true, fillIndex: 0),
        TradeOutcome.sl_hit,
      );
    });

    test('returns tp1_hit when TP1 then breakeven stop stops the remainder', () {
      final candles = _candles(t0, [
        [1.1000, 1.1002, 1.0998, 1.1000],
        [1.1000, 1.1025, 1.0995, 1.1022],
        [1.1022, 1.1028, 1.0995, 1.1002],
      ]);
      expect(
        TradeMonitor.checkOutcome(candles: candles, entry: entry, sl: sl, tp1: tp1, tp2: tp2, isBullish: true, fillIndex: 0),
        TradeOutcome.tp1_hit,
      );
    });

    test('returns tp2_hit when TP2 is reached after TP1', () {
      final candles = _candles(t0, [
        [1.1000, 1.1002, 1.0998, 1.1000],
        [1.1000, 1.1025, 1.0998, 1.1022],
        [1.1022, 1.1065, 1.1020, 1.1060],
      ]);
      expect(
        TradeMonitor.checkOutcome(candles: candles, entry: entry, sl: sl, tp1: tp1, tp2: tp2, isBullish: true, fillIndex: 0),
        TradeOutcome.tp2_hit,
      );
    });

    test('returns open when neither SL nor TP is reached', () {
      final candles = _candles(t0, [
        [1.1000, 1.1002, 1.0998, 1.1000],
        [1.1000, 1.1008, 1.0990, 1.1005],
        [1.1005, 1.1010, 1.0992, 1.1008],
      ]);
      expect(
        TradeMonitor.checkOutcome(candles: candles, entry: entry, sl: sl, tp1: tp1, tp2: tp2, isBullish: true, fillIndex: 0),
        TradeOutcome.open,
      );
    });

    test('returns open when the fill index is the last candle', () {
      final candles = _candles(t0, [
        [1.1000, 1.1005, 1.0990, 1.1002],
      ]);
      expect(
        TradeMonitor.checkOutcome(candles: candles, entry: entry, sl: sl, tp1: tp1, tp2: tp2, isBullish: true, fillIndex: 0),
        TradeOutcome.open,
      );
    });
  });

  group('realizedReturnFor', () {
    test('SL hit loses the full risk', () {
      expect(
        TradeMonitor.realizedReturnFor(signal: _signal(), outcome: TradeOutcome.sl_hit),
        closeTo(100, 1e-9),
      );
    });

    test('TP1 hit banks partial profit, remainder stopped at breakeven', () {
      expect(
        TradeMonitor.realizedReturnFor(signal: _signal(), outcome: TradeOutcome.tp1_hit),
        closeTo(200 * 0.5, 1e-9),
      );
    });

    test('TP2 hit banks partial at TP1 plus remainder at TP2', () {
      expect(
        TradeMonitor.realizedReturnFor(signal: _signal(), outcome: TradeOutcome.tp2_hit),
        closeTo(200 * 0.5 + 300 * 0.5, 1e-9),
      );
    });

    test('open trade has no realized return', () {
      expect(
        TradeMonitor.realizedReturnFor(signal: _signal(), outcome: TradeOutcome.open),
        closeTo(0, 1e-9),
      );
    });
  });
}
