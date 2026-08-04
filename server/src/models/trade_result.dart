import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'trade_signal.dart';

enum TradeOutcome { open, tp1_hit, tp2_hit, sl_hit }

class TradeOutcomeAdapter extends TypeAdapter<TradeOutcome> {
  @override
  final int typeId = 7;

  @override
  TradeOutcome read(BinaryReader reader) => TradeOutcome.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, TradeOutcome obj) => writer.writeByte(obj.index);
}

class TradeResult {
  final String id;
  final String signalId;
  final String pair;
  final SignalType type;
  final double entry;
  final double stopLoss;
  final double takeProfit1;
  final double takeProfit2;
  final double partialClosePercent;
  final double risk;
  final DateTime filledTime;
  final TradeOutcome outcome;
  final double? exitTimeMs;
  final double? exitPrice;
  final double? realizedReturn;

  TradeResult({
    String? id,
    required this.signalId,
    required this.pair,
    required this.type,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit1,
    this.takeProfit2 = 0,
    this.partialClosePercent = 0.5,
    required this.risk,
    DateTime? filledTime,
    this.outcome = TradeOutcome.open,
    this.exitTimeMs,
    this.exitPrice,
    this.realizedReturn,
  })  : id = id ?? const Uuid().v4(),
        filledTime = filledTime ?? DateTime.now().toUtc();

  bool get isWin => outcome == TradeOutcome.tp1_hit || outcome == TradeOutcome.tp2_hit;

  double get realizedRrr {
    switch (outcome) {
      case TradeOutcome.sl_hit:
        return -(realizedReturn ?? risk) / risk;
      case TradeOutcome.tp1_hit:
        return (realizedReturn ?? (takeProfit1 - entry).abs()) / risk;
      case TradeOutcome.tp2_hit:
        final r1 = (takeProfit1 - entry).abs();
        final r2 = takeProfit2 > 0 ? (takeProfit2 - entry).abs() : r1;
        final blended = r1 * partialClosePercent + r2 * (1 - partialClosePercent);
        return (realizedReturn ?? blended) / risk;
      case TradeOutcome.open:
        return 0;
    }
  }

  TradeResult copyWith({
    TradeOutcome? outcome,
    DateTime? exitTime,
    double? exitPrice,
    double? realizedReturn,
  }) {
    return TradeResult(
      id: id,
      signalId: signalId,
      pair: pair,
      type: type,
      entry: entry,
      stopLoss: stopLoss,
      takeProfit1: takeProfit1,
      takeProfit2: takeProfit2,
      partialClosePercent: partialClosePercent,
      risk: risk,
      filledTime: filledTime,
      outcome: outcome ?? this.outcome,
      exitTimeMs: exitTime != null ? exitTime.millisecondsSinceEpoch.toDouble() : exitTimeMs,
      exitPrice: exitPrice ?? this.exitPrice,
      realizedReturn: realizedReturn ?? this.realizedReturn,
    );
  }
}

class TradeResultAdapter extends TypeAdapter<TradeResult> {
  @override
  final int typeId = 6;

  @override
  TradeResult read(BinaryReader reader) {
    final version = reader.readByte();
    final result = TradeResult(
      id: reader.readString(),
      signalId: reader.readString(),
      pair: reader.readString(),
      type: reader.read(),
      entry: reader.readDouble(),
      stopLoss: reader.readDouble(),
      takeProfit1: reader.readDouble(),
      takeProfit2: reader.readDouble(),
      partialClosePercent: reader.readDouble(),
      risk: reader.readDouble(),
      filledTime: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      outcome: reader.read(),
    );
    if (version >= 1) {
      final hasExit = reader.readBool();
      return TradeResult(
        id: result.id,
        signalId: result.signalId,
        pair: result.pair,
        type: result.type,
        entry: result.entry,
        stopLoss: result.stopLoss,
        takeProfit1: result.takeProfit1,
        takeProfit2: result.takeProfit2,
        partialClosePercent: result.partialClosePercent,
        risk: result.risk,
        filledTime: result.filledTime,
        outcome: result.outcome,
        exitTimeMs: hasExit ? reader.readDouble() : null,
        exitPrice: hasExit ? reader.readDouble() : null,
        realizedReturn: hasExit ? reader.readDouble() : null,
      );
    }
    return result;
  }

  @override
  void write(BinaryWriter writer, TradeResult obj) {
    writer.writeByte(1);
    writer.writeString(obj.id);
    writer.writeString(obj.signalId);
    writer.writeString(obj.pair);
    writer.write(obj.type);
    writer.writeDouble(obj.entry);
    writer.writeDouble(obj.stopLoss);
    writer.writeDouble(obj.takeProfit1);
    writer.writeDouble(obj.takeProfit2);
    writer.writeDouble(obj.partialClosePercent);
    writer.writeDouble(obj.risk);
    writer.writeInt(obj.filledTime.millisecondsSinceEpoch);
    writer.write(obj.outcome);
    writer.writeBool(obj.exitTimeMs != null);
    if (obj.exitTimeMs != null) {
      writer.writeDouble(obj.exitTimeMs!);
      writer.writeDouble(obj.exitPrice ?? 0);
      writer.writeDouble(obj.realizedReturn ?? 0);
    }
  }
}
