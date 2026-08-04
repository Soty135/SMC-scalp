import 'package:flutter/material.dart';

import '../models/trade_signal.dart';

Color signalStatusColor(SignalStatus s) {
  switch (s) {
    case SignalStatus.sweep:
      return Colors.amberAccent;
    case SignalStatus.choch:
      return Colors.cyanAccent;
    case SignalStatus.entry:
      return Colors.lightGreenAccent;
    case SignalStatus.filled:
      return Colors.blueAccent;
    case SignalStatus.tp1_hit:
    case SignalStatus.tp2_hit:
      return Colors.greenAccent;
    case SignalStatus.sl_hit:
      return Colors.redAccent;
    case SignalStatus.expired:
      return Colors.grey;
    case SignalStatus.cancelled:
      return Colors.orangeAccent;
  }
}

String signalStatusLabel(SignalStatus s) {
  switch (s) {
    case SignalStatus.sweep:
      return 'SWEEP';
    case SignalStatus.choch:
      return 'CHoCH';
    case SignalStatus.entry:
      return 'ENTRY';
    case SignalStatus.filled:
      return 'FILLED';
    case SignalStatus.tp1_hit:
      return 'TP1 HIT';
    case SignalStatus.tp2_hit:
      return 'TP2 HIT';
    case SignalStatus.sl_hit:
      return 'SL HIT';
    case SignalStatus.expired:
      return 'EXPIRED';
    case SignalStatus.cancelled:
      return 'CANCELLED';
  }
}

Color pairStatusColor(String status) {
  final upper = status.toUpperCase();
  if (upper.startsWith('ERROR')) return Colors.redAccent;
  if (upper.contains('FILLED') || upper.contains('IN TRADE')) {
    return Colors.blueAccent;
  }
  if (upper.contains('ENTRY') || upper.contains('LIMIT')) {
    return Colors.lightGreenAccent;
  }
  if (upper.contains('CHoCH') || upper.contains('CH0CH')) {
    return Colors.cyanAccent;
  }
  if (upper.contains('SWEEP')) return Colors.amberAccent;
  if (upper.contains('FILTER')) return Colors.orangeAccent;
  if (upper.contains('SCANNING')) return Colors.grey;
  if (upper.contains('ERROR')) return Colors.redAccent;
  return Colors.blueGrey;
}
