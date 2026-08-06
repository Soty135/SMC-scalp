import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trade_signal.dart';
import '../providers/analysis_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/signal_provider.dart';
import '../services/web_socket_service.dart';
import '../ui/ui_helpers.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final analysis = context.watch<AnalysisProvider>();
    final settings = context.watch<SettingsProvider>();
    final signals = context.watch<SignalProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMC SCALP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.pushNamed(context, '/performance'),
            tooltip: 'Performance',
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.pushNamed(context, '/signals'),
            tooltip: 'All signals',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(context, analysis, settings),
          if (settings.isAnalysisRunning) ...[
            const SizedBox(height: 4),
            if (analysis.isAnalyzing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0xFF1F2833),
                ),
              ),
            _buildPriceCards(analysis, settings),
          ],
          Expanded(child: _buildRecentSignals(context, signals)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (settings.isAnalysisRunning) {
            analysis.stopAnalysis();
          } else {
            analysis.startAnalysis();
          }
        },
        icon: Icon(settings.isAnalysisRunning ? Icons.stop : Icons.play_arrow),
        label: Text(settings.isAnalysisRunning ? 'STOP' : 'START ANALYSIS'),
        backgroundColor: settings.isAnalysisRunning
            ? Colors.redAccent
            : const Color(0xFF00E5A0),
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    AnalysisProvider analysis,
    SettingsProvider settings,
  ) {
    final running = settings.isAnalysisRunning;
    final wsState = analysis.connectionState;
    final wsLabel = wsState == WsConnectionState.connected
        ? 'CONNECTED'
        : wsState == WsConnectionState.reconnecting
            ? 'RECONNECTING'
            : 'DISCONNECTED';
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              running ? Icons.circle : Icons.circle_outlined,
              color: running ? const Color(0xFF00E5A0) : Colors.grey,
              size: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.statusMessage,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    running
                        ? 'WS: $wsLabel · '
                            '${settings.selectedPairs.length} pairs · every '
                            '30s'
                        : 'Idle — tap START ANALYSIS',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8A97A5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connection: $wsLabel',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8A97A5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCards(AnalysisProvider analysis, SettingsProvider settings) {
    final pairs = settings.selectedPairs;

    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: pairs.length,
        itemBuilder: (context, i) {
          final pair = pairs[i];
          final price = analysis.currentPrices[pair];
          final status = analysis.pairStatuses[pair] ?? 'Waiting…';
          final color = pairStatusColor(status);

          return Card(
            margin: const EdgeInsets.only(right: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    pair,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price?.toStringAsFixed(5) ?? '----',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 132,
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSignals(
    BuildContext context,
    SignalProvider signals,
  ) {
    final recent = signals.signals.take(30).toList();

    if (recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: const Color(0xFF2A3642)),
            const SizedBox(height: 16),
            const Text(
              'NO SIGNALS YET',
              style: TextStyle(color: Color(0xFF8A97A5), fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap START ANALYSIS to begin scanning',
              style: TextStyle(color: Color(0xFF5A6672), fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text(
                'SIGNAL FEED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Color(0xFF8A97A5),
                ),
              ),
              const Spacer(),
              Text(
                '${signals.activeSignals.length} active',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF00E5A0),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: recent.length,
            itemBuilder: (context, i) {
              final s = recent[i];
              return _signalTile(context, s);
            },
          ),
        ),
      ],
    );
  }

  Widget _signalTile(BuildContext context, TradeSignal s) {
    final isBuy = s.isBuy;
    final dirColor = isBuy ? const Color(0xFF00E5A0) : const Color(0xFFFF5A5F);
    final statusColor = signalStatusColor(s.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          isBuy ? Icons.trending_up : Icons.trending_down,
          color: dirColor,
        ),
        title: Text(
          '${s.pair}  ${isBuy ? 'BUY' : 'SELL'}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          s.status == SignalStatus.entry || s.status == SignalStatus.filled
              ? 'ENTRY ${s.entry.toStringAsFixed(5)} · '
                  'RR ${s.rrr1.toStringAsFixed(2)}'
              : s.poolType.isEmpty
                  ? s.status.name
                  : '${s.poolType} → ${s.poiType}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A97A5)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        onTap: () {
          Navigator.pushNamed(context, '/signal-detail', arguments: s);
        },
      ),
    );
  }
}
