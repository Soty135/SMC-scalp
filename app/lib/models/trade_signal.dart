import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum SignalType { buy, sell }

class SignalTypeAdapter extends TypeAdapter<SignalType> {
  @override
  final int typeId = 2;

  @override
  SignalType read(BinaryReader reader) => SignalType.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, SignalType obj) => writer.writeByte(obj.index);
}

enum SignalStatus {
  sweep,
  choch,
  entry,
  filled,
  tp1_hit,
  tp2_hit,
  sl_hit,
  expired,
  cancelled,
}

class SignalStatusAdapter extends TypeAdapter<SignalStatus> {
  @override
  final int typeId = 3;

  @override
  SignalStatus read(BinaryReader reader) => SignalStatus.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, SignalStatus obj) => writer.writeByte(obj.index);
}

class TradeSignal {
  final String id;
  final String pair;
  final SignalType type;
  final SignalStatus status;

  // Phase 1 — 15m sweep + POI
  final String poolType;
  final double? sweepLevel;
  final double sweepExtreme;
  final String poiType;
  final double? poiTop;
  final double? poiBottom;

  // Phase 2 — 5m CHoCH
  final double? chochLevel;
  final double? chochDisplacementAtr;

  // Phase 3 — 1m entry
  final String entryZoneType;
  final double? entryZoneTop;
  final double? entryZoneBottom;

  final double entry;
  final double stopLoss;
  final double takeProfit1;
  final double takeProfit2;
  final double risk;
  final double rrr1;
  final double rrr2;
  final double spreadAtSignal;
  final double? slMovedToBe;

  final DateTime createdAt;
  final String reason;
  final DateTime? filledTime;
  final double? filledPrice;
  final DateTime? exitTime;
  final double? exitPrice;

  TradeSignal({
    String? id,
    required this.pair,
    required this.type,
    this.status = SignalStatus.entry,
    this.poolType = '',
    this.sweepLevel,
    required this.sweepExtreme,
    this.poiType = '',
    this.poiTop,
    this.poiBottom,
    this.chochLevel,
    this.chochDisplacementAtr,
    this.entryZoneType = '',
    this.entryZoneTop,
    this.entryZoneBottom,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit1,
    required this.takeProfit2,
    required this.risk,
    required this.rrr1,
    required this.rrr2,
    this.spreadAtSignal = 0,
    this.slMovedToBe,
    DateTime? createdAt,
    this.reason = '',
    this.filledTime,
    this.filledPrice,
    this.exitTime,
    this.exitPrice,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toUtc();

  bool get isBuy => type == SignalType.buy;
  bool get isOpen =>
      status == SignalStatus.sweep ||
      status == SignalStatus.choch ||
      status == SignalStatus.entry ||
      status == SignalStatus.filled;

  double get reward1 => (takeProfit1 - entry).abs();
  double get reward2 => takeProfit2 > 0 ? (takeProfit2 - entry).abs() : 0;

  TradeSignal copyWith({
    SignalStatus? status,
    String? poolType,
    double? sweepLevel,
    double? sweepExtreme,
    String? poiType,
    double? poiTop,
    double? poiBottom,
    double? chochLevel,
    double? chochDisplacementAtr,
    String? entryZoneType,
    double? entryZoneTop,
    double? entryZoneBottom,
    double? entry,
    double? stopLoss,
    double? takeProfit1,
    double? takeProfit2,
    double? risk,
    double? rrr1,
    double? rrr2,
    double? spreadAtSignal,
    double? slMovedToBe,
    DateTime? filledTime,
    double? filledPrice,
    DateTime? exitTime,
    double? exitPrice,
    String? reason,
  }) {
    return TradeSignal(
      id: id,
      pair: pair,
      type: type,
      status: status ?? this.status,
      poolType: poolType ?? this.poolType,
      sweepLevel: sweepLevel ?? this.sweepLevel,
      sweepExtreme: sweepExtreme ?? this.sweepExtreme,
      poiType: poiType ?? this.poiType,
      poiTop: poiTop ?? this.poiTop,
      poiBottom: poiBottom ?? this.poiBottom,
      chochLevel: chochLevel ?? this.chochLevel,
      chochDisplacementAtr: chochDisplacementAtr ?? this.chochDisplacementAtr,
      entryZoneType: entryZoneType ?? this.entryZoneType,
      entryZoneTop: entryZoneTop ?? this.entryZoneTop,
      entryZoneBottom: entryZoneBottom ?? this.entryZoneBottom,
      entry: entry ?? this.entry,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit1: takeProfit1 ?? this.takeProfit1,
      takeProfit2: takeProfit2 ?? this.takeProfit2,
      risk: risk ?? this.risk,
      rrr1: rrr1 ?? this.rrr1,
      rrr2: rrr2 ?? this.rrr2,
      spreadAtSignal: spreadAtSignal ?? this.spreadAtSignal,
      slMovedToBe: slMovedToBe ?? this.slMovedToBe,
      createdAt: createdAt,
      reason: reason ?? this.reason,
      filledTime: filledTime ?? this.filledTime,
      filledPrice: filledPrice ?? this.filledPrice,
      exitTime: exitTime ?? this.exitTime,
      exitPrice: exitPrice ?? this.exitPrice,
    );
  }
}

class TradeSignalAdapter extends TypeAdapter<TradeSignal> {
  @override
  final int typeId = 5;

  @override
  TradeSignal read(BinaryReader reader) {
    reader.readByte();
    final id = reader.readString();
    final pair = reader.readString();
    final type = reader.read();
    final status = reader.read();
    final poolType = reader.readString();
    final sweepLevel = reader.readDouble();
    final sweepExtreme = reader.readDouble();
    final poiType = reader.readString();
    final poiTop = reader.readDouble();
    final poiBottom = reader.readDouble();
    final chochLevel = reader.readDouble();
    final chochDisplacementAtr = reader.readDouble();
    final entryZoneType = reader.readString();
    final entryZoneTop = reader.readDouble();
    final entryZoneBottom = reader.readDouble();
    final entry = reader.readDouble();
    final stopLoss = reader.readDouble();
    final takeProfit1 = reader.readDouble();
    final takeProfit2 = reader.readDouble();
    final risk = reader.readDouble();
    final rrr1 = reader.readDouble();
    final rrr2 = reader.readDouble();
    final spreadAtSignal = reader.readDouble();
    final slMovedToBe = reader.readDouble();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final reason = reader.readString();
    final hasFill = reader.readBool();
    final hasExit = reader.readBool();

    return TradeSignal(
      id: id,
      pair: pair,
      type: type,
      status: status,
      poolType: poolType,
      sweepLevel: _nullable(sweepLevel),
      sweepExtreme: sweepExtreme,
      poiType: poiType,
      poiTop: _nullable(poiTop),
      poiBottom: _nullable(poiBottom),
      chochLevel: _nullable(chochLevel),
      chochDisplacementAtr: _nullable(chochDisplacementAtr),
      entryZoneType: entryZoneType,
      entryZoneTop: _nullable(entryZoneTop),
      entryZoneBottom: _nullable(entryZoneBottom),
      entry: entry,
      stopLoss: stopLoss,
      takeProfit1: takeProfit1,
      takeProfit2: takeProfit2,
      risk: risk,
      rrr1: rrr1,
      rrr2: rrr2,
      spreadAtSignal: spreadAtSignal,
      slMovedToBe: _nullable(slMovedToBe),
      createdAt: createdAt,
      reason: reason,
      filledTime: hasFill
          ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
          : null,
      filledPrice: hasFill ? reader.readDouble() : null,
      exitTime: hasExit
          ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
          : null,
      exitPrice: hasExit ? reader.readDouble() : null,
    );
  }

  static double? _nullable(double v) => v == -1 ? null : v;
  static double _orNeg(double? v) => v ?? -1;

  @override
  void write(BinaryWriter writer, TradeSignal obj) {
    writer.writeByte(1);
    writer.writeString(obj.id);
    writer.writeString(obj.pair);
    writer.write(obj.type);
    writer.write(obj.status);
    writer.writeString(obj.poolType);
    writer.writeDouble(_orNeg(obj.sweepLevel));
    writer.writeDouble(obj.sweepExtreme);
    writer.writeString(obj.poiType);
    writer.writeDouble(_orNeg(obj.poiTop));
    writer.writeDouble(_orNeg(obj.poiBottom));
    writer.writeDouble(_orNeg(obj.chochLevel));
    writer.writeDouble(_orNeg(obj.chochDisplacementAtr));
    writer.writeString(obj.entryZoneType);
    writer.writeDouble(_orNeg(obj.entryZoneTop));
    writer.writeDouble(_orNeg(obj.entryZoneBottom));
    writer.writeDouble(obj.entry);
    writer.writeDouble(obj.stopLoss);
    writer.writeDouble(obj.takeProfit1);
    writer.writeDouble(obj.takeProfit2);
    writer.writeDouble(obj.risk);
    writer.writeDouble(obj.rrr1);
    writer.writeDouble(obj.rrr2);
    writer.writeDouble(obj.spreadAtSignal);
    writer.writeDouble(_orNeg(obj.slMovedToBe));
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeString(obj.reason);
    writer.writeBool(obj.filledTime != null);
    writer.writeBool(obj.exitTime != null);
    if (obj.filledTime != null) {
      writer.writeInt(obj.filledTime!.millisecondsSinceEpoch);
      writer.writeDouble(obj.filledPrice ?? 0);
    }
    if (obj.exitTime != null) {
      writer.writeInt(obj.exitTime!.millisecondsSinceEpoch);
      writer.writeDouble(obj.exitPrice ?? 0);
    }
  }
}
