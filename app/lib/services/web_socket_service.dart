import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import '../models/tick.dart';

class WebSocketService {
  HubConnection? _connection;
  final _tickController = StreamController<Tick>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  bool _isConnected = false;
  final Set<String> _subscribed = {};

  Stream<Tick> get tickStream => _tickController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    _connection = HubConnectionBuilder()
        .withUrl('https://biquote.io/hubs/tick')
        .withAutomaticReconnect()
        .build();

    _connection!.on('ReceiveTick', (List<dynamic>? args) {
      if (args != null && args.isNotEmpty) {
        try {
          _tickController.add(Tick.fromJson(args[0] as Map<String, dynamic>));
        } catch (_) {}
      }
    });

    _connection!.onreconnected((_) {
      _isConnected = true;
      _connectionController.add(true);
      if (_subscribed.isNotEmpty) {
        _connection?.invoke('Subscribe', args: [_subscribed.toList()]);
      }
    });

    _connection!.onclose((Exception? exception) {
      _isConnected = false;
      _connectionController.add(false);
    });

    await _connection!.start();
    _isConnected = true;
    _connectionController.add(true);
  }

  Future<void> subscribe(List<String> symbols) async {
    _subscribed.addAll(symbols);
    if (_connection != null && _isConnected) {
      await _connection!.invoke('Subscribe', args: [symbols]);
    }
  }

  Future<void> unsubscribe(List<String> symbols) async {
    _subscribed.removeAll(symbols);
    if (_connection != null && _isConnected) {
      await _connection!.invoke('Unsubscribe', args: [symbols]);
    }
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    _tickController.close();
    _connectionController.close();
    disconnect();
  }
}
