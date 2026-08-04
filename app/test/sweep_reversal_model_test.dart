import 'package:flutter_test/flutter_test.dart';

import 'package:smc_scalp_app/models/candle.dart';
import 'package:smc_scalp_app/models/tick.dart';
import 'package:smc_scalp_app/models/trade_signal.dart';
import 'package:smc_scalp_app/services/news_service.dart';
import 'package:smc_scalp_app/smc/liquidity.dart';
import 'package:smc_scalp_app/smc/sweep_reversal_model.dart';

Candle _c(DateTime t, double o, double h, double l, double cl) =>
    Candle(openTime: t, open: o, high: h, low: l, close: cl);

/// 30 x 5m candles: swing high 1.0970 at index 8, then displacement candle
/// (body 0.0020 > 1x ATR14) closing 1.0990 at index 15.
List<Candle> _chochCandles(DateTime t0) {
  const rows = <List<double>>[
    [1.0930, 1.0938, 1.0928, 1.0935],
    [1.0935, 1.0940, 1.0932, 1.0937],
    [1.0937, 1.0942, 1.0934, 1.0940],
    [1.0940, 1.0945, 1.0938, 1.0943],
    [1.0943, 1.0946, 1.0940, 1.0942],
    [1.0942, 1.0947, 1.0941, 1.0945],
    [1.0945, 1.0952, 1.0944, 1.0950],
    [1.0950, 1.0954, 1.0949, 1.0952],
    [1.0952, 1.0970, 1.0950, 1.0966],
    [1.0966, 1.0962, 1.0948, 1.0952],
    [1.0952, 1.0958, 1.0946, 1.0948],
    [1.0948, 1.0952, 1.0944, 1.0946],
    [1.0946, 1.0950, 1.0942, 1.0944],
    [1.0944, 1.0948, 1.0940, 1.0942],
    [1.0942, 1.0946, 1.0938, 1.0940],
    [1.0970, 1.0995, 1.0968, 1.0990],
  ];
  final candles = <Candle>[];
  for (int i = 0; i < rows.length; i++) {
    candles.add(_c(
      t0.add(Duration(minutes: 5 * i)),
      rows[i][0], rows[i][1], rows[i][2], rows[i][3],
    ));
  }
  for (int k = 16; k < 30; k++) {
    final base = 1.0990 + (k - 16) * 0.0003;
    candles.add(_c(
      t0.add(Duration(minutes: 5 * k)),
      base, base + 0.0004, base - 0.0003, base + 0.0002,
    ));
  }
  return candles;
}

SweepContext _longCtx({DateTime? sweepTime, double sweepExtreme = 1.0950}) =>
    SweepContext(
      direction: SignalType.buy,
      sweptPool: const LiquidityPool(type: 'eql', level: 1.0945, side: PoolSide.sellSide),
      sweepExtreme: sweepExtreme,
      sweepTime: sweepTime ?? DateTime.utc(2026, 1, 2, 8, 0),
      poi: const PoI(type: 'FVG', isBullish: true, top: 1.0962, bottom: 1.0958, index: 3),
      pools: const [LiquidityPool(type: 'swing_high', level: 1.1020, side: PoolSide.buySide)],
      pois: const [],
    );

EntryPlan _plan({double rrr2 = 3.0}) => EntryPlan(
      zoneType: 'bullish FVG',
      zoneTop: 1.0965,
      zoneBottom: 1.0960,
      entry: 1.0965,
      stopLoss: 1.09485,
      takeProfit1: 1.0998,
      takeProfit2: 1.1020,
      risk: 0.00165,
      rrr1: 2.0,
      rrr2: rrr2,
    );

void main() {
  group('detectChoch', () {
    test('confirms CHoCH with candle displacement after a swing above the swept extreme', () {
      final t0 = DateTime.utc(2026, 1, 2, 8, 0);
      final ctx = _longCtx(sweepTime: t0.subtract(const Duration(minutes: 1)));

      final res = SweepReversalModel.detectChoch(ctx: ctx, candles5m: _chochCandles(t0));

      expect(res, isNotNull);
      expect(res!.confirmed, isTrue);
      expect(res.referenceLevel, closeTo(1.0970, 1e-9));
      expect(res.candleIndex, 15);
      expect(res.displacementType, 'candle');
    });

    test('returns null when no candle closes beyond the swing', () {
      final t0 = DateTime.utc(2026, 1, 2, 8, 0);
      final ctx = _longCtx(sweepTime: t0.subtract(const Duration(minutes: 1)));
      final candles = _chochCandles(t0);
      final capped = candles
          .map((c) => _c(c.openTime, c.open, c.high, c.low, 1.0960))
          .toList();

      expect(SweepReversalModel.detectChoch(ctx: ctx, candles5m: capped), isNull);
    });
  });

  group('buildEntryPlan', () {
    test('selects the deepest bullish FVG (lowest gapTop) and enters at its proximal edge', () {
      final t0 = DateTime.utc(2026, 1, 2, 8, 0);
      // Two unmitigated bullish FVGs: shallow at 1.0985 (index 6), deep at
      // 1.0965 (index 1). The model must pick the deepest one.
      final oneMin = <Candle>[
        _c(t0.add(Duration(minutes: 0)), 1.0958, 1.0960, 1.0952, 1.0958),
        _c(t0.add(Duration(minutes: 1)), 1.0958, 1.0965, 1.0965, 1.0962),
        _c(t0.add(Duration(minutes: 2)), 1.0962, 1.0966, 1.0966, 1.0964),
        _c(t0.add(Duration(minutes: 3)), 1.0964, 1.0970, 1.0967, 1.0969),
        _c(t0.add(Duration(minutes: 4)), 1.0969, 1.0972, 1.0966, 1.0970),
        _c(t0.add(Duration(minutes: 5)), 1.0970, 1.0984, 1.0982, 1.0982),
        _c(t0.add(Duration(minutes: 6)), 1.0982, 1.0985, 1.0985, 1.0983),
        _c(t0.add(Duration(minutes: 7)), 1.0983, 1.0988, 1.0986, 1.0987),
        _c(t0.add(Duration(minutes: 8)), 1.0988, 1.0991, 1.0987, 1.0990),
      ];
      for (int k = 9; k < 30; k++) {
        final base = 1.0990 + (k - 9) * 0.0002;
        oneMin.add(_c(t0.add(Duration(minutes: k)), base, base + 0.0004, base - 0.0002, base + 0.0002));
      }
      final ctx = _longCtx(sweepTime: t0);
      final choch = ChochResult(
        confirmed: true,
        referenceLevel: 1.0970,
        candleIndex: 8,
        candleTime: t0.add(const Duration(minutes: 8)),
        displacementAtr: 0.0012,
        displacementType: 'candle',
      );

      final plan = SweepReversalModel.buildEntryPlan(
        ctx: ctx, choch: choch, candles1m: oneMin, symbol: 'EURUSD',
      );

      expect(plan, isNotNull);
      expect(plan!.zoneType, 'bullish FVG');
      expect(plan.zoneTop, closeTo(1.0965, 1e-9));
      expect(plan.zoneBottom, closeTo(1.0960, 1e-9));
      expect(plan.entry, closeTo(1.0965, 1e-9));
      expect(plan.isLong, isTrue);
      expect(plan.takeProfit2, closeTo(1.1020, 1e-9));
      expect(plan.rrr2, closeTo(3.3333, 0.001));
    });

    test('returns null with too few 1m candles', () {
      final t0 = DateTime.utc(2026, 1, 2, 8, 0);
      final choch = ChochResult(
        confirmed: true,
        referenceLevel: 1.0970,
        candleIndex: 0,
        candleTime: t0,
        displacementAtr: 0.001,
        displacementType: 'candle',
      );
      final plan = SweepReversalModel.buildEntryPlan(
        ctx: _longCtx(sweepTime: t0),
        choch: choch,
        candles1m: [_c(t0, 1.09, 1.10, 1.08, 1.09)],
        symbol: 'EURUSD',
      );
      expect(plan, isNull);
    });
  });

  group('evaluateEntryGate', () {
    final now = DateTime.utc(2026, 1, 2, 12, 0);

    test('Filter 1: blocks when more than 20 1m candles elapsed after CHoCH', () {
      final candles = <Candle>[];
      for (int i = 0; i < 21; i++) {
        candles.add(_c(now.add(Duration(minutes: i)), 1.09, 1.10, 1.08, 1.09));
      }
      final res = SweepReversalModel.evaluateEntryGate(
        plan: _plan(), chochTime: now, candles1m: candles,
        tick: null, highImpactEvents: const [], now: now,
      );
      expect(res.allowed, isFalse);
      expect(res.reason, contains('Filter 1'));
    });

    test('Filter 2: blocks when spread exceeds 15% of SL distance', () {
      final candles = <Candle>[_c(now, 1.09, 1.10, 1.08, 1.09)];
      final tick = Tick(
        symbol: 'EURUSD', bid: 1.0965, ask: 1.0968, last: 1.0965,
        mid: 1.09665, spread: 0.0003, time: now,
      );
      final res = SweepReversalModel.evaluateEntryGate(
        plan: _plan(), chochTime: now, candles1m: candles,
        tick: tick, highImpactEvents: const [], now: now,
      );
      expect(res.allowed, isFalse);
      expect(res.reason, contains('Filter 2'));
    });

    test('Filter 3: blocks when high-impact news is within 30 minutes', () {
      final candles = <Candle>[_c(now, 1.09, 1.10, 1.08, 1.09)];
      final events = [
        CalendarEvent(
          id: 'e1', name: 'NFP', time: now.add(const Duration(minutes: 10)),
          countryCode: 'US', currency: 'USD', importance: 'high',
        ),
      ];
      final res = SweepReversalModel.evaluateEntryGate(
        plan: _plan(), chochTime: now, candles1m: candles,
        tick: null, highImpactEvents: events, now: now,
      );
      expect(res.allowed, isFalse);
      expect(res.reason, contains('Filter 3'));
    });

    test('Filter 4: blocks when RRR to TP2 is below 2.0', () {
      final candles = <Candle>[_c(now, 1.09, 1.10, 1.08, 1.09)];
      final res = SweepReversalModel.evaluateEntryGate(
        plan: _plan(rrr2: 1.5), chochTime: now, candles1m: candles,
        tick: null, highImpactEvents: const [], now: now,
      );
      expect(res.allowed, isFalse);
      expect(res.reason, contains('Filter 4'));
    });

    test('allows entry when every filter passes', () {
      final candles = <Candle>[_c(now, 1.09, 1.10, 1.08, 1.09)];
      final res = SweepReversalModel.evaluateEntryGate(
        plan: _plan(), chochTime: now, candles1m: candles,
        tick: null, highImpactEvents: const [], now: now,
      );
      expect(res.allowed, isTrue);
      expect(res.reason, isEmpty);
    });
  });

  group('checkExtremeReset', () {
    final t0 = DateTime.utc(2026, 1, 2, 8, 0);

    test('triggers when a 5m candle violates the swept extreme', () {
      // EURUSD: buffer = 5 pips = 0.0005 -> threshold 1.0945.
      final candles = [_c(t0, 1.0942, 1.0948, 1.0944, 1.0946)];
      expect(
        SweepReversalModel.checkExtremeReset(
          ctx: _longCtx(sweepTime: t0.subtract(const Duration(minutes: 1))),
          candles5m: candles, symbol: 'EURUSD',
        ),
        isTrue,
      );
    });

    test('stays valid when price respects the swept extreme', () {
      final candles = [_c(t0, 1.0948, 1.0952, 1.0946, 1.0950)];
      expect(
        SweepReversalModel.checkExtremeReset(
          ctx: _longCtx(sweepTime: t0.subtract(const Duration(minutes: 1))),
          candles5m: candles, symbol: 'EURUSD',
        ),
        isFalse,
      );
    });
  });
}
