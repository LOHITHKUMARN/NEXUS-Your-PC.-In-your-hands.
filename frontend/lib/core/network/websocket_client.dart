import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/network/api_client.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class TelemetryWebSocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _staleCheckTimer;

  String _host = "127.0.0.1";
  int _port = 8765;
  String _apiKey = "";
  String? _lastError;

  int _reconnectAttempts = 0;
  DateTime? _lastFrameReceived;

  final _telemetryController = StreamController<UnifiedTelemetryFrameModel>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _latencyController = StreamController<int>.broadcast();
  final _staleController = StreamController<bool>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;
  String get host => _host;
  int get port => _port;
  String get apiKey => _apiKey;
  String? get lastError => _lastError;
  DateTime? get lastFrameReceived => _lastFrameReceived;

  bool get isStale {
    if (_status != ConnectionStatus.connected) return true;
    if (_lastFrameReceived == null) return true;
    return DateTime.now().difference(_lastFrameReceived!).inMilliseconds > 2500;
  }

  int? get secondsSinceLastFrame {
    if (_lastFrameReceived == null) return null;
    return DateTime.now().difference(_lastFrameReceived!).inSeconds;
  }

  Stream<UnifiedTelemetryFrameModel> get telemetryStream => _telemetryController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<int> get latencyStream => _latencyController.stream;
  Stream<bool> get staleStream => _staleController.stream;

  bool _manuallyClosed = false;
  int _lastPingSent = 0;

  void configure({required String host, required int port, required String apiKey}) {
    final shouldReconnect = (_host != host || _port != port || _apiKey != apiKey);
    _host = host;
    _port = port;
    _apiKey = apiKey;

    if (shouldReconnect) {
      _reconnectAttempts = 0;
      if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) {
        disconnect();
      }
      connect();
    }
  }

  void onAppResumed() {
    if (_status != ConnectionStatus.connected) {
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      connect();
    }
  }

  void connect() {
    _manuallyClosed = false;
    _reconnectTimer?.cancel();

    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) {
      return;
    }

    _lastError = null;
    _updateStatus(ConnectionStatus.connecting);

    // Bootstrap instant telemetry frame via HTTP snapshot while WS establishes
    apiClient.getTelemetrySnapshot().then((snapshot) {
      if (snapshot != null && _status != ConnectionStatus.connected) {
        _lastFrameReceived = DateTime.now();
        _telemetryController.add(snapshot);
      }
    }).catchError((_) {});

    runZonedGuarded(() async {
      try {
        final wsUri = Uri.parse('ws://$_host:$_port/api/telemetry/ws?api_key=$_apiKey');
        final channel = WebSocketChannel.connect(wsUri);
        _channel = channel;

        // Wait for connection readiness
        try {
          await channel.ready;
        } catch (readyErr) {
          _lastError = readyErr.toString();
        }

        _subscription = channel.stream.listen(
          (message) {
            _lastError = null;
            _reconnectAttempts = 0;

            if (_status != ConnectionStatus.connected) {
              _updateStatus(ConnectionStatus.connected);
              _startPingTimer();
              _startStaleCheckTimer();
            }

            if (message == "pong") {
              if (_lastPingSent > 0) {
                final latency = DateTime.now().millisecondsSinceEpoch - _lastPingSent;
                _latencyController.add(latency);
              }
              return;
            }

            try {
              final Map<String, dynamic> data = jsonDecode(message);
              final frame = UnifiedTelemetryFrameModel.fromJson(data);
              _lastFrameReceived = DateTime.now();
              _staleController.add(false);
              _telemetryController.add(frame);
            } catch (_) {}
          },
          onError: (err) {
            _lastError = err.toString();
            _updateStatus(ConnectionStatus.error);
            _scheduleReconnect();
          },
          onDone: () {
            _updateStatus(ConnectionStatus.disconnected);
            if (!_manuallyClosed) {
              _scheduleReconnect();
            }
          },
          cancelOnError: true,
        );
      } catch (e) {
        _lastError = e.toString();
        _updateStatus(ConnectionStatus.error);
        _scheduleReconnect();
      }
    }, (error, stack) {
      _lastError = error.toString();
      _updateStatus(ConnectionStatus.error);
      _scheduleReconnect();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_status == ConnectionStatus.connected && _channel != null) {
        _lastPingSent = DateTime.now().millisecondsSinceEpoch;
        try {
          _channel!.sink.add("ping");
        } catch (_) {}
      }
    });
  }

  void _startStaleCheckTimer() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == ConnectionStatus.connected) {
        _staleController.add(isStale);
      }
    });
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _staleCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_manuallyClosed) return;

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, max 16s with random jitter (+/- 20%)
    final baseSeconds = min(16, pow(2, min(_reconnectAttempts - 1, 4)).toInt());
    final jitter = (Random().nextDouble() * 0.4 - 0.2) * baseSeconds;
    final totalDelay = Duration(milliseconds: max(500, ((baseSeconds + jitter) * 1000).toInt()));

    _reconnectTimer = Timer(totalDelay, () {
      if (!_manuallyClosed && _status != ConnectionStatus.connected) {
        connect();
      }
    });
  }

  void disconnect() {
    _manuallyClosed = true;
    _pingTimer?.cancel();
    _staleCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  void _updateStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
    _staleController.add(newStatus != ConnectionStatus.connected);
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
    _statusController.close();
    _latencyController.close();
    _staleController.close();
  }
}

final telemetryWsClient = TelemetryWebSocketClient();

