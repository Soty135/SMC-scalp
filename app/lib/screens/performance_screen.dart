import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trade_result.dart';
import '../models/trade_signal.dart';
import '../providers/performance_provider.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final perf = context.watch<PerformanceProvider>();
    final stats = perf.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PERFORMANCE'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSummaryCards(context, stats),
          const SizedBox(height: 12),
          if (stats.byPair.isNotEmpty) _buildPairBreakdown(stats),
          const SizedBox(height: 12),
          _buildTradeList(context, perf),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, PerformanceStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(context, 'TRADES', '${stats.totalTrades}',
                  Icons.bar_chart, const Color(0xFF64B5F6)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                  context,
                  'WIN RATE',
                  '${(stats.winRate * 100).toStringAsFixed(0)}%',
                  Icons.emoji_events,
                  const Color(0xFF00E5A0)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statCard(context, 'AVG R',
                  stats.avgRealizedRrr.toStringAsFixed(2), Icons.trending_up,
                  const Color(0xFFFFB74D)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(context, 'OPEN', '${stats.open}',
                  Icons.hourglass_empty, const Color(0xFF8A97A5)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
      BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8A97A5),
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairBreakdown(PerformanceStats stats) {
    final entries = stats.byPair.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BY PAIR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Color(0xFF8A97A5),
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map((e) {
              final p = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        e.key,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: p.total == 0 ? 0 : p.wins / p.total,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF1F2833),
                          color: const Color(0xFF00E5A0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${p.wins}W/${p.losses}L',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF8A97A5)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${p.winRate * 100 > 0 ? (p.winRate * 100).toStringAsFixed(0) : '0'}%',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF00E5A0),
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeList(BuildContext context, PerformanceProvider perf) {
    final trades = perf.trades;
    if (trades.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.show_chart, size: 48, color: const Color(0xFF2A3642)),
                const SizedBox(height: 12),
                const Text(
                  'NO TRADES TRACKED YET',
                  style: TextStyle(color: Color(0xFF8A97A5), fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Filled signals appear here automatically',
                  style: TextStyle(color: Color(0xFF5A6672), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'TRADE HISTORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFF8A97A5),
            ),
          ),
        ),
        ...trades.map((t) => _tradeTile(t)),
      ],
    );
  }

  Widget _tradeTile(TradeResult t) {
    final isBuy = t.type == SignalType.buy;

    IconData outcomeIcon;
    Color outcomeColor;
    String outcomeText;

    switch (t.outcome) {
      case TradeOutcome.tp2_hit:
        outcomeIcon = Icons.check_circle;
        outcomeColor = const Color(0xFF00E5A0);
        outcomeText = 'TP2';
      case TradeOutcome.tp1_hit:
        outcomeIcon = Icons.check_circle_outline;
        outcomeColor = const Color(0xFF69F0AE);
        outcomeText = 'TP1';
      case TradeOutcome.sl_hit:
        outcomeIcon = Icons.cancel;
        outcomeColor = const Color(0xFFFF5252);
        outcomeText = 'SL';
      case TradeOutcome.open:
        outcomeIcon = Icons.hourglass_empty;
        outcomeColor = const Color(0xFFFFB74D);
        outcomeText = 'OPEN';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          isBuy ? Icons.trending_up : Icons.trending_down,
          color: isBuy ? const Color(0xFF00E5A0) : const Color(0xFFFF5A5F),
          size: 20,
        ),
        title: Text(
          '${t.pair}  ${isBuy ? 'BUY' : 'SELL'}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Entry ${t.entry.toStringAsFixed(5)} · '
          'R ${t.realizedRrr.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A97A5)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(outcomeIcon, color: outcomeColor, size: 16),
            const SizedBox(width: 4),
            Text(
              outcomeText,
              style: TextStyle(
                fontSize: 10,
                color: outcomeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
