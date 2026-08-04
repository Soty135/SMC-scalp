import 'package:hive/hive.dart';

enum Timeframe {
  m1,
  m5,
  m15,
  h1,
  d1;

  String get apiValue {
    switch (this) {
      case Timeframe.m1:
        return '1m';
      case Timeframe.m5:
        return '5m';
      case Timeframe.m15:
        return '15m';
      case Timeframe.h1:
        return '1h';
      case Timeframe.d1:
        return '1d';
    }
  }

  int get minutes {
    switch (this) {
      case Timeframe.m1:
        return 1;
      case Timeframe.m5:
        return 5;
      case Timeframe.m15:
        return 15;
      case Timeframe.h1:
        return 60;
      case Timeframe.d1:
        return 1440;
    }
  }

  static Timeframe fromApiValue(String value) {
    switch (value) {
      case '1m':
        return Timeframe.m1;
      case '5m':
        return Timeframe.m5;
      case '15m':
        return Timeframe.m15;
      case '1h':
        return Timeframe.h1;
      case '1d':
        return Timeframe.d1;
      default:
        return Timeframe.h1;
    }
  }
}

class TimeframeAdapter extends TypeAdapter<Timeframe> {
  @override
  final int typeId = 0;

  @override
  Timeframe read(BinaryReader reader) {
    return Timeframe.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, Timeframe obj) {
    writer.writeByte(obj.index);
  }
}
