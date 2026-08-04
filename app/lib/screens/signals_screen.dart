import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trade_signal.dart';
import '../providers/signal_provider.dart';
import '../ui/ui_helpers.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final signals = context.watch<SignalProvider>();
    final allSignals = signals.signals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGNALS'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear All'),
                    content: const Text('Delete all signals?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          signals.clearAll();
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Delete All',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear All')),
            ],
          ),
        ],
      ),
      body: allSignals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 56, color: const Color(0xFF2A3642)),
                  const SizedBox(height: 12),
                  const Text(
                    'NO SIGNALS YET',
                    style: TextStyle(color: Color(0xFF8A97A5), fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: allSignals.length,
              itemBuilder: (context, i) {
                final s = allSignals[i];
                return Dismissible(
                  key: Key(s.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Signal'),
                      content: Text(
                        'Delete ${s.pair} ${s.isBuy ? 'BUY' : 'SELL'}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) => signals.deleteSignal(s.id),
                  child: _signalTile(context, s),
                );
              },
            ),
    );
  }

  Widget _signalTile(BuildContext context, TradeSignal s) {
    final isBuy = s.isBuy;
    final dirColor = isBuy ? const Color(0xFF00E5A0) : const Color(0xFFFF5A5F);
    final statusColor = signalStatusColor(s.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(isBuy ? Icons.trending_up : Icons.trending_down,
            color: dirColor),
        title: Text(
          '${s.pair}  ${isBuy ? 'BUY' : 'SELL'}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          s.status == SignalStatus.entry || s.status == SignalStatus.filled
              ? 'Entry ${s.entry.toStringAsFixed(5)} · RR1 ${s.rrr1.toStringAsFixed(2)}'
              : s.status == SignalStatus.choch
                  ? 'CHoCH @ ${s.chochLevel?.toStringAsFixed(5)}'
                  : s.poolType.isEmpty
                      ? s.status.name
                      : '${s.poolType} → ${s.poiType}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A97A5)),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                signalStatusLabel(s.status),
                style: TextStyle(
                  fontSize: 9,
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(s.createdAt),
              style: const TextStyle(fontSize: 9, color: Color(0xFF5A6672)),
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(context, '/signal-detail', arguments: s);
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour < 12 ? 'AM' : 'PM';
    return '${local.month.toString().padLeft(2, "0")}-'
        '${local.day.toString().padLeft(2, "0")} '
        '${h.toString().padLeft(2, "0")}:'
        '${local.minute.toString().padLeft(2, "0")} $amPm';
  }
}
