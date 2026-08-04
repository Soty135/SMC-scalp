import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/performance_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/signal_provider.dart';
import '../services/fcm_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final fcm = context.watch<FcmService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('PAIRS'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: AppConfig.defaultPairs
                  .map(
                    (pair) => CheckboxListTile(
                      dense: true,
                      title: Text(
                        pair,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      value: settings.selectedPairs.contains(pair),
                      activeColor: const Color(0xFF00E5A0),
                      onChanged: (_) => settings.togglePair(pair),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('PUSH SERVER'),
          const SizedBox(height: 8),
          _buildServerCard(context, settings, fcm),
          const SizedBox(height: 24),
          const _SectionHeader('STRATEGY'),
          const SizedBox(height: 8),
          _buildStrategyCard(),
          const SizedBox(height: 24),
          const _SectionHeader('DANGER ZONE'),
          const SizedBox(height: 8),
          _buildDangerZone(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildServerCard(
    BuildContext context,
    SettingsProvider settings,
    FcmService fcm,
  ) {
    final controller = TextEditingController(text: settings.serverUrl);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://10.0.2.2:8080',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  settings.setServerUrl(controller.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Server URL saved'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('SAVE'),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Icon(
                  fcm.available
                      ? Icons.verified_user
                      : Icons.error_outline,
                  color: fcm.available
                      ? const Color(0xFF00E5A0)
                      : const Color(0xFFFFB74D),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fcm.available ? 'FCM registered' : 'FCM unavailable',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (fcm.registerError.isNotEmpty)
                        Text(
                          fcm.registerError,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFB74D),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: fcm.available
                      ? () => fcm.registerWithServer()
                      : null,
                  child: const Text('RE-REGISTER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '15m → 5m → 1m Liquidity Sweep Reversal',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              'Phase 1: aggressive 15m liquidity sweep + POI tap.\n'
              'Phase 2: 5m CHoCH with displacement (body > 1× ATR).\n'
              'Phase 3: 1m limit at proximal edge of deepest FVG (or deepest OB).\n'
              'SL: beyond sweep extreme. TP1: 1:2, 50% partial + SL→BE. '
              'TP2: opposing pool/POI.\n\n'
              'Filters: retracement >20×1m candles, spread >15% of SL, '
              'high-impact news ±30 min, RRR-to-TP2 < 1:2.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8A97A5), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final signals = context.read<SignalProvider>();
    final perf = context.read<PerformanceProvider>();

    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.list_alt, color: Color(0xFFFFB74D)),
            title: const Text('Clear all signals',
                style: TextStyle(fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
              onPressed: () => _confirmClear(
                context,
                'Delete all signals?',
                () => signals.clearAll(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.bar_chart, color: Color(0xFFFFB74D)),
            title: const Text('Clear all trade results',
                style: TextStyle(fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
              onPressed: () => _confirmClear(
                context,
                'Delete all trade results?',
                () => perf.clearAll(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Color(0xFF8A97A5),
      ),
    );
  }
}
