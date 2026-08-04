import 'dart:async';
import '../config/app_config.dart';
import 'api_client.dart';

class CalendarEvent {
  final String id;
  final String name;
  final DateTime time;
  final String countryCode;
  final String currency;
  final String importance;
  final double? actual;
  final double? forecast;
  final double? previous;

  const CalendarEvent({
    required this.id,
    required this.name,
    required this.time,
    required this.countryCode,
    required this.currency,
    required this.importance,
    this.actual,
    this.forecast,
    this.previous,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      time: DateTime.tryParse(json['time'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      countryCode: json['countryCode'] as String? ?? '',
      currency: json['currency'] as String? ?? '',
      importance: json['importance'] as String? ?? 'low',
      actual: (json['actual'] as num?)?.toDouble(),
      forecast: (json['forecast'] as num?)?.toDouble(),
      previous: (json['previous'] as num?)?.toDouble(),
    );
  }

  bool get isUpcoming => actual == null;
}

class NewsService {
  final ApiClient _api;
  List<CalendarEvent> _cache = [];
  DateTime? _lastFetched;
  bool _fetching = false;
  Timer? _refreshTimer;

  NewsService(this._api);

  List<CalendarEvent> get cachedEvents => _cache;
  DateTime? get lastFetched => _lastFetched;
  bool get isStale =>
      _lastFetched == null ||
      DateTime.now().difference(_lastFetched!).inMinutes >
          AppConfig.newsCacheRefreshMinutes;

  Future<void> start() async {
    await refresh();
    _refreshTimer ??= Timer.periodic(
      Duration(minutes: AppConfig.newsCacheRefreshMinutes),
      (_) => refresh(),
    );
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final now = DateTime.now().toUtc();
      final raw = await _api.fetchCalendar(
        from: now.subtract(Duration(hours: AppConfig.newsLookbackHours)),
        to: now.add(Duration(hours: AppConfig.newsLookaheadHours)),
      );
      _cache = raw
          .map(CalendarEvent.fromJson)
          .where((e) => e.importance == 'high')
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      _lastFetched = now;
    } catch (_) {
      // Keep stale cache; refresh will retry on next cycle.
    } finally {
      _fetching = false;
    }
  }

  bool hasHighImpactNear(DateTime time, {int windowMinutes = AppConfig.newsWindowMinutes}) {
    final target = time.toUtc();
    return _cache.any((e) {
      final diff = e.time.difference(target).inMinutes.abs();
      return diff <= windowMinutes;
    });
  }

  List<CalendarEvent> upcomingWithin(int minutes) {
    final now = DateTime.now().toUtc();
    return _cache
        .where((e) =>
            e.time.isAfter(now) &&
            e.time.difference(now).inMinutes <= minutes)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }
}
