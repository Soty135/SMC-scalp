import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../models/trade_signal.dart';
import '../providers/signal_provider.dart';
import '../ui/ui_helpers.dart';

class SignalDetailScreen extends StatelessWidget {
  final TradeSignal signal;

  const SignalDetailScreen({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final isBuy = signal.isBuy;

    return Scaffold(
      appBar: AppBar(
        title: Text('${signal.pair}  ${isBuy ? 'BUY' : 'SELL'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Signal'),
                  content: Text('Delete this ${signal.pair} signal?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<SignalProvider>().deleteSignal(signal.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            TradeLevelsChart(
              tp2: signal.takeProfit2 > 0 ? signal.takeProfit2 : null,
              tp1: signal.takeProfit1,
              entry: signal.entry,
              sl: signal.stopLoss,
              zoneTop: signal.entryZoneTop,
              zoneBottom: signal.entryZoneBottom,
              zoneLabel: signal.entryZoneType,
              isLong: isBuy,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(context),
            const SizedBox(height: 12),
            _buildReasonCard(),
            if (signal.exitTime != null) ...[
              const SizedBox(height: 12),
              _buildExitCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isBuy = signal.isBuy;
    final dirColor = isBuy ? const Color(0xFF00E5A0) : const Color(0xFFFF5A5F);
    final statusColor = signalStatusColor(signal.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isBuy ? Icons.trending_up : Icons.trending_down,
              size: 40,
              color: dirColor,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${signal.pair} ${isBuy ? 'LONG' : 'SHORT'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    signalStatusLabel(signal.status),
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final dateFormat = intl.DateFormat('yyyy-MM-dd HH:mm');
    final isBuy = signal.isBuy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Sweep Pool', signal.poolType.isEmpty ? '—' : signal.poolType),
            _row('Sweep Level', signal.sweepLevel?.toStringAsFixed(5) ?? '—'),
            _row(
              'Sweep Extreme',
              '${signal.sweepExtreme.toStringAsFixed(5)} '
              '(${isBuy ? 'low' : 'high'})',
            ),
            _row('15m POI', signal.poiType.isEmpty ? '—' : signal.poiType),
            const Divider(),
            _row(
              'Entry Zone',
              signal.entryZoneType.isEmpty ? '—' : signal.entryZoneType,
            ),
            _row(
              'Zone Range',
              signal.entryZoneTop != null && signal.entryZoneBottom != null
                  ? '${signal.entryZoneTop!.toStringAsFixed(5)} – '
                      '${signal.entryZoneBottom!.toStringAsFixed(5)}'
                  : '—',
            ),
            _row('Entry (limit)', signal.entry.toStringAsFixed(5)),
            _row('Stop Loss', signal.stopLoss.toStringAsFixed(5)),
            const Divider(),
            _row('Take Profit 1', signal.takeProfit1.toStringAsFixed(5)),
            if (signal.takeProfit2 > 0)
              _row('Take Profit 2', signal.takeProfit2.toStringAsFixed(5)),
            _row('RR1', '1:${signal.rrr1.toStringAsFixed(2)}'),
            _row('RR2',
                signal.rrr2 > 0 ? '1:${signal.rrr2.toStringAsFixed(2)}' : '—'),
            if (signal.chochLevel != null)
              _row('5m CHoCH', signal.chochLevel!.toStringAsFixed(5)),
            _row('Spread at signal', signal.spreadAtSignal.toStringAsFixed(5)),
            if (signal.filledTime != null)
              _row('Filled', dateFormat.format(signal.filledTime!.toLocal())),
            _row('Created', dateFormat.format(signal.createdAt.toLocal())),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ANALYSIS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Color(0xFF8A97A5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              signal.reason.isEmpty ? '—' : signal.reason,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitCard() {
    final dateFormat = intl.DateFormat('yyyy-MM-dd HH:mm');
    final isBuy = signal.isBuy;
    final exitPrice = signal.exitPrice;
    final entry = signal.entry;
    final pnlPips = exitPrice != null
        ? (isBuy ? exitPrice - entry : entry - exitPrice)
        : 0.0;
    final pnlColor =
        pnlPips >= 0 ? const Color(0xFF00E5A0) : const Color(0xFFFF5A5F);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(
              'Exit Time',
              signal.exitTime == null
                  ? '—'
                  : dateFormat.format(signal.exitTime!.toLocal()),
            ),
            _row('Exit Price', exitPrice?.toStringAsFixed(5) ?? '—'),
            _row(
              'P&L (price units)',
              '${pnlPips >= 0 ? '+' : ''}${pnlPips.toStringAsFixed(5)}',
              valueColor: pnlColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8A97A5), fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: valueColor ?? Colors.white,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class TradeLevelsChart extends StatelessWidget {
  final double? tp2;
  final double tp1;
  final double entry;
  final double sl;
  final double? zoneTop;
  final double? zoneBottom;
  final String zoneLabel;
  final bool isLong;

  const TradeLevelsChart({
    super.key,
    this.tp2,
    required this.tp1,
    required this.entry,
    required this.sl,
    this.zoneTop,
    this.zoneBottom,
    this.zoneLabel = '',
    required this.isLong,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CustomPaint(
          size: const Size(double.infinity, 240),
          painter: _LevelsChartPainter(
            tp2: tp2,
            tp1: tp1,
            entry: entry,
            sl: sl,
            zoneTop: zoneTop,
            zoneBottom: zoneBottom,
            zoneLabel: zoneLabel,
            isLong: isLong,
          ),
        ),
      ),
    );
  }
}

class _LevelsChartPainter extends CustomPainter {
  final double? tp2;
  final double tp1;
  final double entry;
  final double sl;
  final double? zoneTop;
  final double? zoneBottom;
  final String zoneLabel;
  final bool isLong;

  _LevelsChartPainter({
    this.tp2,
    required this.tp1,
    required this.entry,
    required this.sl,
    this.zoneTop,
    this.zoneBottom,
    this.zoneLabel = '',
    required this.isLong,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      sl,
      entry,
      tp1,
      if (tp2 != null) tp2!,
      if (zoneTop != null) zoneTop!,
      if (zoneBottom != null) zoneBottom!,
    ];
    var minP = values.reduce(math.min);
    var maxP = values.reduce(math.max);
    final span = maxP - minP;
    if (span == 0) {
      minP -= 1;
      maxP += 1;
    }
    final pad = (maxP - minP) * 0.2;
    final pLow = minP - pad;
    final pHigh = maxP + pad;

    double yFor(double p) =>
        size.height - ((p - pLow) / (pHigh - pLow)) * size.height;

    // Zone band
    if (zoneTop != null && zoneBottom != null) {
      final yTop = yFor(zoneTop!);
      final yBottom = yFor(zoneBottom!);
      final top = math.min(yTop, yBottom);
      final bottom = math.max(yTop, yBottom);
      final zoneColor =
          isLong ? const Color(0xFF00E5A0) : const Color(0xFFFF5A5F);
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()..color = zoneColor.withValues(alpha: 0.10),
      );
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = zoneColor.withValues(alpha: 0.35),
      );
      if (zoneLabel.isNotEmpty) {
        _label(canvas, size, zoneLabel.toUpperCase(),
            (top + bottom) / 2 - 8.0, zoneColor, 8.0);
      }
    }

    _level(canvas, size, 'TP2', tp2, yFor, const Color(0xFFFFB74D));
    _level(canvas, size, 'TP1', tp1, yFor, const Color(0xFF69F0AE));
    _level(canvas, size, 'ENTRY', entry, yFor, Colors.white);
    _level(canvas, size, 'SL', sl, yFor, const Color(0xFFFF5252));
  }

  void _level(
    Canvas canvas,
    Size size,
    String label,
    double? value,
    double Function(double) yFor,
    Color color,
  ) {
    if (value == null) return;
    final y = yFor(value);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    _label(canvas, size, label, y - 9.0, color, 10.0);
    _label(
      canvas,
      size,
      value.toStringAsFixed(5),
      y - 9.0,
      color,
      10.0,
      alignRight: true,
    );
  }

  void _label(
    Canvas canvas,
    Size size,
    String text,
    double top,
    Color color,
    double fontSize, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          backgroundColor: const Color(0xB00B0F14),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? size.width - tp.width - 6.0 : 6.0;
    tp.paint(canvas, Offset(dx, top));
  }

  @override
  bool shouldRepaint(covariant _LevelsChartPainter oldDelegate) {
    return oldDelegate.entry != entry ||
        oldDelegate.tp1 != tp1 ||
        oldDelegate.sl != sl ||
        oldDelegate.tp2 != tp2 ||
        oldDelegate.zoneTop != zoneTop ||
        oldDelegate.zoneBottom != zoneBottom;
  }
}
