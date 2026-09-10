import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:pc_control_center/core/network/websocket_client.dart' show ConnectionStatus;

class InputWebSocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _moveFlushTimer;

  String _host = "127.0.0.1";
  int _port = 8765;
  String _apiKey = "";

  double _bufferedDx = 0.0;
  double _bufferedDy = 0.0;
  double _currentSensitivity = 1.2;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _status = ConnectionStatus.disconnected;

  ConnectionStatus get status => _status;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  bool _isDisposed = false;

  void configure({required String host, required int port, required String apiKey}) {
    final shouldReconnect = (_host != host || _port != port || _apiKey != apiKey);
    _host = host;
    _port = port;
    _apiKey = apiKey;

    if (shouldReconnect && (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting)) {
      disconnect();
      connect();
    }
  }

  void connect() {
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) {
      return;
    }

    _setStatus(ConnectionStatus.connecting);
    _reconnectTimer?.cancel();

    try {
      final wsUri = Uri(
        scheme: 'ws',
        host: _host,
        port: _port,
        path: '/api/input/ws',
        queryParameters: _apiKey.isNotEmpty ? {'api_key': _apiKey} : null,
      );

      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        (message) {
          // Input socket receives responses such as pong or status confirmations
        },
        onDone: () {
          _setStatus(ConnectionStatus.disconnected);
          _scheduleReconnect();
        },
        onError: (err) {
          debugPrint('Input WS error: $err');
          _setStatus(ConnectionStatus.error);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _setStatus(ConnectionStatus.connected);
      _startMoveThrottleTimer();
    } catch (e) {
      debugPrint('Failed to connect Input WS: $e');
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _setStatus(ConnectionStatus s) {
    if (_status != s) {
      _status = s;
      _statusController.add(_status);
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_status != ConnectionStatus.connected) {
        connect();
      }
    });
  }

  void _startMoveThrottleTimer() {
    _moveFlushTimer?.cancel();
    // Flush buffered movement at ~85Hz (approx 12ms intervals) for smooth tracking without network saturation
    _moveFlushTimer = Timer.periodic(const Duration(milliseconds: 12), (_) {
      _flushBufferedMove();
    });
  }

  void _flushBufferedMove() {
    if (_bufferedDx == 0.0 && _bufferedDy == 0.0) return;
    if (_status != ConnectionStatus.connected || _channel == null) {
      _bufferedDx = 0.0;
      _bufferedDy = 0.0;
      return;
    }

    final dx = _bufferedDx;
    final dy = _bufferedDy;
    _bufferedDx = 0.0;
    _bufferedDy = 0.0;

    _sendJson({
      "t": "move",
      "dx": dx,
      "dy": dy,
      "sens": _currentSensitivity,
    });
  }

  /// High-frequency touch displacement accumulation
  void sendMove(double dx, double dy, {double sensitivity = 1.2}) {
    _currentSensitivity = sensitivity;
    _bufferedDx += dx;
    _bufferedDy += dy;
  }

  /// Mouse click down, up, tap, or double
  void sendClick(String button, String action) {
    _flushBufferedMove();
    _sendJson({
      "t": "click",
      "button": button,
      "action": action,
    });
  }

  /// Scroll wheel displacement
  void sendScroll(double dy, {double dx = 0.0, bool natural = true}) {
    _sendJson({
      "t": "scroll",
      "dy": dy,
      "dx": dx,
      "natural": natural,
    });
  }

  /// Single virtual key
  void sendKey(String code, {String action = "tap"}) {
    _sendJson({
      "t": "key",
      "code": code,
      "action": action,
    });
  }

  /// Unicode text / emoji typing
  void sendText(String text) {
    if (text.isEmpty) return;
    _sendJson({
      "t": "text",
      "value": text,
    });
  }

  /// Key combination
  void sendCombo(List<String> keys) {
    if (keys.isEmpty) return;
    _sendJson({
      "t": "combo",
      "keys": keys,
    });
  }

  void _sendJson(Map<String, dynamic> data) {
    if (_status != ConnectionStatus.connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('Error sending input packet: $e');
    }
  }

  void disconnect() {
    _moveFlushTimer?.cancel();
    _moveFlushTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _statusController.close();
  }
}

// Global instance for reuse across trackpad session
final inputWsClient = InputWebSocketClient();
