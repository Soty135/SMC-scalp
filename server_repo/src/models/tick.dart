class Tick {
  final String symbol;
  final double bid;
  final double ask;
  final double last;
  final double mid;
  final double spread;
  final DateTime time;
  final double? high;
  final double? low;
  final double? dayDiffPercent;

  const Tick({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.last,
    required this.mid,
    required this.spread,
    required this.time,
    this.high,
    this.low,
    this.dayDiffPercent,
  });

  factory Tick.fromJson(Map<String, dynamic> json) {
    final bid = (json['bid'] as num?)?.toDouble() ?? 0;
    final ask = (json['ask'] as num?)?.toDouble() ?? 0;
    return Tick(
      symbol: json['symbol'] as String? ?? '',
      bid: bid,
      ask: ask,
      last: (json['last'] as num?)?.toDouble() ?? 0,
      mid: (json['mid'] as num?)?.toDouble() ?? (bid + ask) / 2,
      spread: (json['spread'] as num?)?.toDouble() ?? (ask - bid).abs(),
      time: DateTime.tryParse(json['timestamp'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      dayDiffPercent: (json['dayDiffPercent'] as num?)?.toDouble(),
    );
  }
}
