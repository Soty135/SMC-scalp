import 'package:flutter_test/flutter_test.dart';

import 'package:smc_scalp_app/models/trade_result.dart';
import 'package:smc_scalp_app/models/trade_signal.dart';

TradeSignal _signal() => TradeSignal(
      pair: 'EURUSD',
      type: SignalType.buy,
      sweepExtreme: 1.0949,
      entry: 1000,
      stopLoss: 900,
      takeProfit1: 1200,
      takeProfit2: 1300,
      risk: 100,
      rrr1: 2.0,
      rrr2: 3.0,
    );

TradeResult _result() => TradeResult(
      signalId: 'sig-1',
      pair: 'EURUSD',
      type: SignalType.buy,
      entry: 1000,
      stopLoss: 900,
      takeProfit1: 1200,
      takeProfit2: 1300,
      risk: 100,
      filledTime: DateTime.utc(2026, 1, 2, 8, 0),
    );

void main() {
  group('TradeSignal', () {
    test('copyWith updates only the requested fields and keeps identity', () {
      final s = _signal().copyWith(status: SignalStatus.sweep, slMovedToBe: 1.0950);
      final updated = s.copyWith(status: SignalStatus.filled);

      expect(updated.status, SignalStatus.filled);
      expect(updated.slMovedToBe, 1.0950);
      expect(updated.id, s.id);
      expect(updated.pair, 'EURUSD');
      expect(updated.entry, 1000);
      expect(updated.takeProfit1, 1200);
    });

    test('isOpen is true for active statuses and false for terminal ones', () {
      for (final st in SignalStatus.values) {
        final active = st == SignalStatus.sweep ||
            st == SignalStatus.choch ||
            st == SignalStatus.entry ||
            st == SignalStatus.filled;
        expect(_signal().copyWith(status: st).isOpen, active, reason: 'status $st');
      }
    });

    test('reward getters reflect distance to targets', () {
      final s = _signal();
      expect(s.reward1, 200);
      expect(s.reward2, 300);
    });
  });

  group('TradeResult.realizedRrr', () {
    test('SL hit with realized return equals risk -> -1.0R', () {
      final r = _result().copyWith(outcome: TradeOutcome.sl_hit, realizedReturn: 100);
      expect(r.realizedRrr, closeTo(-1.0, 1e-9));
    });

    test('SL hit with no realized return falls back to risk', () {
      expect(_result().copyWith(outcome: TradeOutcome.sl_hit).realizedRrr, closeTo(-1.0, 1e-9));
    });

    test('TP1 hit realized RRR equals the blended partial result', () {
      final r = _result().copyWith(outcome: TradeOutcome.tp1_hit, realizedReturn: 100);
      expect(r.realizedRrr, closeTo(1.0, 1e-9));
    });

    test('TP2 hit blends partial TP1 and remainder TP2', () {
      final r = _result().copyWith(outcome: TradeOutcome.tp2_hit);
      // 200 * 0.5 + 300 * 0.5 = 250 -> 2.5R
      expect(r.realizedRrr, closeTo(2.5, 1e-9));
    });

    test('open trade has zero RRR', () {
      expect(_result().realizedRrr, closeTo(0, 1e-9));
    });
  });
}
