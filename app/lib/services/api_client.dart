import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/candle.dart';
import '../models/tick.dart';
import '../models/timeframe.dart';

class ApiClient {
  final http.Client _client;
  final String baseUrl;

  ApiClient({http.Client? client, this.baseUrl = AppConfig.baseUrl})
      : _client = client ?? http.Client();

  Future<T> _retry<T>(
    String description,
    Future<T> Function() action, {
    int retries = 3,
  }) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        return await action();
      } on SocketException catch (e) {
        if (attempt == retries) rethrow;
        final delay = Duration(seconds: 2 * (attempt + 1));
        stdout.writeln(
          '[${DateTime.now()}] $description DNS error: $e'
          ' — retrying in ${delay.inSeconds}s (attempt ${attempt + 1}/$retries)',
        );
        await Future.delayed(delay);
      } on FormatException catch (e) {
        if (attempt == retries) rethrow;
        final delay = Duration(seconds: 2 * (attempt + 1));
        stdout.writeln(
          '[${DateTime.now()}] $description connection error: $e'
          ' — retrying in ${delay.inSeconds}s (attempt ${attempt + 1}/$retries)',
        );
        await Future.delayed(delay);
      } catch (e) {
        if (attempt == retries) rethrow;
        await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
      }
    }
    throw ApiException('$description failed after $retries retries');
  }

  Future<List<Candle>> fetchOhlc(
    String symbol,
    Timeframe timeframe, {
    int limit = AppConfig.maxCandlesPerRequest,
  }) async {
    return _retry('fetchOhlc($symbol)', () async {
      final url = Uri.parse('$baseUrl/api/$symbol/ohlc')
          .replace(queryParameters: {
        'interval': timeframe.apiValue,
        'limit': limit.toString(),
      });

      final response = await _client.get(url);

      if (response.statusCode != 200) {
        throw ApiException('Failed to fetch OHLC data: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final bars = data['bars'] as List<dynamic>;

      return bars
          .map((b) => Candle.fromJson(b as Map<String, dynamic>))
          .where((c) => !c.isOpen)
          .toList()
        ..sort((a, b) => a.openTime.compareTo(b.openTime));
    });
  }

  Future<Tick> fetchLatestTick(String symbol) async {
    return _retry('fetchLatestTick($symbol)', () async {
      final url = Uri.parse('$baseUrl/api/$symbol');
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException('Failed to fetch tick: ${response.statusCode}');
      }
      return Tick.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    });
  }

  Future<Map<String, Tick>> fetchLatestTicks(List<String> symbols) async {
    return _retry('fetchLatestTicks', () async {
      final url = Uri.parse('$baseUrl/api/latest').replace(queryParameters: {
        for (final s in symbols) 'symbols': s,
      });
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException('Failed to fetch ticks: ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (data is List) {
        return {
          for (final t in data) (t as Map<String, dynamic>)['symbol'] as String: Tick.fromJson(t),
        };
      }
      return {};
    });
  }

  Future<List<Map<String, dynamic>>> fetchCalendar({
    required DateTime from,
    required DateTime to,
    List<String> countries = AppConfig.newsCountries,
    String importance = 'high',
  }) async {
    return _retry('fetchCalendar', () async {
      final url = Uri.parse('$baseUrl/api/calendar').replace(queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'countries': countries.join(','),
        'importance': importance,
        'limit': '500',
      });
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException('Failed to fetch calendar: ${response.statusCode}');
      }
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    });
  }

  Future<List<Map<String, dynamic>>> fetchActiveSymbols() async {
    return _retry('fetchActiveSymbols', () async {
      final url = Uri.parse('$baseUrl/api/active');
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw ApiException('Failed to fetch symbols: ${response.statusCode}');
      }
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    });
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
