import 'dart:async';
import 'package:signalr_core/signalr_core.dart';
import '../models/tick.dart';

enum ConnectionState { connected, reconnecting, disconnected }

class WebSocketService {
  HubConnection? _connection;
  final _tickController = StreamController<Tick>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;
  final Set<String> _subscribed = {};

  Stream<Tick> get tickStream => _tickController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<ConnectionState> get stateStream => _stateController.stream;
  ConnectionState get connectionState => _state;
  bool get isConnected => _state == ConnectionState.connected;

  Future<void> connect() async {
    if (_state == ConnectionState.connected) return;

    _connection = HubConnectionBuilder()
        .withUrl('https://biquote.io/hubs/tick')
        .withAutomaticReconnect(_reconnectPolicy)
        .build();

    _connection!.on('ReceiveTick', (List<dynamic>? args) {
      if (args != null && args.isNotEmpty) {
        try {
          _tickController.add(Tick.fromJson(args[0] as Map<String, dynamic>));
        } catch (_) {}
      }
    });

    _connection!.onreconnecting((Exception? exception) {
      _state = ConnectionState.reconnecting;
      _stateController.add(_state);
      _connectionController.add(false);
    });

    _connection!.onreconnected((_) {
      _state = ConnectionState.connected;
      _stateController.add(_state);
      _connectionController.add(true);
      if (_subscribed.isNotEmpty) {
        _connection?.invoke('Subscribe', args: [_subscribed.toList()]);
      }
    });

    _connection!.onclose((Exception? exception) {
      _state = ConnectionState.disconnected;
      _stateController.add(_state);
      _connectionController.add(false);
    });

    await _connection!.start();
    _state = ConnectionState.connected;
    _stateController.add(_state);
    _connectionController.add(true);
  }

  static final _reconnectPolicy = [
    0,
    1000,
    3000,
    5000,
    10000,
    30000,
    null,
  ];

  Future<void> subscribe(List<String> symbols) async {
    _subscribed.addAll(symbols);
    if (_connection != null && _state == ConnectionState.connected) {
      await _connection!.invoke('Subscribe', args: [symbols]);
    }
  }

  Future<void> unsubscribe(List<String> symbols) async {
    _subscribed.removeAll(symbols);
    if (_connection != null && _state == ConnectionState.connected) {
      await _connection!.invoke('Unsubscribe', args: [symbols]);
    }
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
    _connectionController.add(false);
  }

  void dispose() {
    _tickController.close();
    _connectionController.close();
    _stateController.close();
    disconnect();
  }
}
