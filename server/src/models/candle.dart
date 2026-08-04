class Candle {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final int tickVolume;
  final bool isOpen;

  const Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
    this.tickVolume = 0,
    this.isOpen = false,
  });

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      openTime: DateTime.parse(json['openTime'] as String).toUtc(),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      tickVolume: (json['tickVolume'] as num?)?.toInt() ?? 0,
      isOpen: json['isOpen'] as bool? ?? false,
    );
  }

  bool get isBullish => close >= open;
  bool get isBearish => close < open;
  double get body => (close - open).abs();
  double get upperWick => high - (isBullish ? close : open);
  double get lowerWick => (isBullish ? open : close) - low;
  double get range => high - low;
}
