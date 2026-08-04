import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

import 'src/config/app_config.dart';
import 'src/models/tick.dart';
import 'src/models/timeframe.dart';
import 'src/models/trade_signal.dart';
import 'src/services/api_client.dart';
import 'src/services/news_service.dart';
import 'src/smc/sweep_reversal_model.dart';

void main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final projectId = Platform.environment['FCM_PROJECT_ID'] ?? 'smc-scalp';
  final serviceAccountJson = Platform.environment['FCM_SERVICE_ACCOUNT_JSON'];

  if (serviceAccountJson == null || serviceAccountJson.isEmpty) {
    stderr.writeln('ERROR: FCM_SERVICE_ACCOUNT_JSON environment variable not set.');
    stderr.writeln('Set it to the full JSON string of your Firebase service account key.');
    exit(1);
  }

  final credentials =
      ServiceAccountCredentials.fromJson(jsonDecode(serviceAccountJson));
  final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  final api = ApiClient();
  final news = NewsService(api);
  await news.refresh();
  Timer.periodic(
    Duration(minutes: AppConfig.newsCacheRefreshMinutes),
    (_) => news.refresh(),
  );

  final tokens = <String>{};

  Future<void> runAnalysis() async {
    if (tokens.isEmpty) {
      stdout.writeln('[${DateTime.now()}] No device token registered yet. Waiting...');
      return;
    }

    final now = DateTime.now().toUtc();
    for (final pair in AppConfig.defaultPairs) {
      try {
        final candles1d = await api.fetchOhlc(pair, Timeframe.d1, limit: 200);
        final candles15m = await api.fetchOhlc(pair, Timeframe.m15, limit: 200);
        final candles5m = await api.fetchOhlc(pair, Timeframe.m5, limit: 200);
        final candles1m = await api.fetchOhlc(pair, Timeframe.m1, limit: 200);

        final sweep = SweepReversalModel.detectSweepTap(
          symbol: pair,
          candles15m: candles15m,
          candles1d: candles1d,
        );
        if (sweep == null) continue;

        final choch = SweepReversalModel.detectChoch(ctx: sweep, candles5m: candles5m);
        if (choch == null) continue;

        final plan = SweepReversalModel.buildEntryPlan(
          ctx: sweep,
          choch: choch,
          candles1m: candles1m,
          symbol: pair,
        );
        if (plan == null) continue;

        Tick? tick;
        try {
          tick = await api.fetchLatestTick(pair);
        } catch (_) {
          // Filter 2 (spread) is skipped when no live tick is available.
        }

        final gate = SweepReversalModel.evaluateEntryGate(
          plan: plan,
          chochTime: choch.candleTime,
          candles1m: candles1m,
          tick: tick,
          highImpactEvents: news.cachedEvents,
          now: now,
        );

        if (!gate.allowed) {
          stdout.writeln('[${DateTime.now()}] $pair rejected: ${gate.reason}');
          continue;
        }

        final signal = TradeSignal(
          pair: pair,
          type: sweep.isLong ? SignalType.buy : SignalType.sell,
          poolType: sweep.sweptPool.type,
          sweepLevel: sweep.sweptPool.level,
          sweepExtreme: sweep.sweepExtreme,
          poiType: sweep.poi.type,
          poiTop: sweep.poi.top,
          poiBottom: sweep.poi.bottom,
          chochLevel: choch.referenceLevel,
          chochDisplacementAtr: choch.displacementAtr,
          entryZoneType: plan.zoneType,
          entryZoneTop: plan.zoneTop,
          entryZoneBottom: plan.zoneBottom,
          entry: plan.entry,
          stopLoss: plan.stopLoss,
          takeProfit1: plan.takeProfit1,
          takeProfit2: plan.takeProfit2 ?? 0,
          risk: plan.risk,
          rrr1: plan.rrr1,
          rrr2: plan.rrr2,
          status: SignalStatus.entry,
          reason:
              '${sweep.sweptPool.type} swept -> CHoCH @${choch.referenceLevel.toStringAsFixed(5)} -> ${plan.zoneType}',
        );

        stdout.writeln(
          '[${DateTime.now()}] ENTRY: $pair ${signal.isBuy ? "BUY" : "SELL"} '
          '@${signal.entry.toStringAsFixed(5)} | SL: ${signal.stopLoss.toStringAsFixed(5)} '
          '| TP1: ${signal.takeProfit1.toStringAsFixed(5)} | TP2: ${signal.takeProfit2.toStringAsFixed(5)} '
          '| RRR: ${signal.rrr2.toStringAsFixed(2)} | ${plan.zoneType}',
        );

        final title = 'ENTRY: $pair ${signal.isBuy ? "BUY" : "SELL"}';
        final body = 'Entry: ${signal.entry.toStringAsFixed(5)} | '
            'SL: ${signal.stopLoss.toStringAsFixed(5)} | '
            'TP1: ${signal.takeProfit1.toStringAsFixed(5)} | '
            'TP2: ${signal.takeProfit2.toStringAsFixed(5)}';

        for (final token in tokens) {
          await sendPush(projectId, credentials, scopes, token, title, body, {
            'pair': pair,
            'type': signal.isBuy ? 'BUY' : 'SELL',
            'status': signal.status.name,
            'entry': signal.entry.toString(),
            'stopLoss': signal.stopLoss.toString(),
            'takeProfit1': signal.takeProfit1.toString(),
            'takeProfit2': signal.takeProfit2.toString(),
            'rrr': signal.rrr2.toString(),
            'entryZone': plan.zoneType,
          });
        }
      } catch (e) {
        stderr.writeln('[${DateTime.now()}] Error analyzing $pair: $e');
      }
    }
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Server running on port $port');

  await for (final request in server) {
    if (request.method == 'POST' && request.uri.path == '/register') {
      final body = await utf8.decodeStream(request);
      final data = jsonDecode(body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        tokens.add(token);
        stdout.writeln('Device token registered: ${token.substring(0, min(20, token.length))}...');
      }
      request.response
        ..statusCode = 200
        ..write('{"status":"ok"}')
        ..close();
    } else if (request.method == 'GET' && request.uri.path == '/analyze') {
      await runAnalysis();
      request.response
        ..statusCode = 200
        ..write('{"status":"ok"}')
        ..close();
    } else if (request.method == 'GET' && request.uri.path == '/health') {
      request.response
        ..statusCode = 200
        ..write(
          '{"status":"healthy","token_registered":${tokens.isNotEmpty},"tokens":${tokens.length}}',
        )
        ..close();
    } else {
      request.response
        ..statusCode = 404
        ..write('{"error":"not found"}')
        ..close();
    }
  }
}

int min(int a, int b) => a < b ? a : b;

Future<void> sendPush(
  String projectId,
  ServiceAccountCredentials credentials,
  List<String> scopes,
  String deviceToken,
  String title,
  String body,
  Map<String, String> data,
) async {
  final client = await clientViaServiceAccount(credentials, scopes);
  try {
    final response = await client.post(
      Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
      body: jsonEncode({
        'message': {
          'token': deviceToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
        },
      }),
    );

    if (response.statusCode == 200) {
      stdout.writeln('FCM push sent successfully');
    } else {
      stderr.writeln('FCM error ${response.statusCode}: ${response.body}');
    }
  } finally {
    client.close();
  }
}
