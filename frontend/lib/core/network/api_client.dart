import 'package:dio/dio.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';

enum ConnectionTestStatus {
  success,
  invalidApiKey,
  unreachable,
}

class ConnectionTestResult {
  final ConnectionTestStatus status;
  final String? hostname;
  final int? latencyMs;
  final String message;

  ConnectionTestResult({
    required this.status,
    this.hostname,
    this.latencyMs,
    required this.message,
  });

  bool get isSuccess => status == ConnectionTestStatus.success;
}

class ParsedPairingUri {
  final String host;
  final int port;
  final String apiKey;
  final String? name;

  ParsedPairingUri({required this.host, required this.port, required this.apiKey, this.name});
}

ParsedPairingUri? parsePairingUri(String input) {
  final trimmed = input.trim();
  if (trimmed.startsWith('pcc://')) {
    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host;
      final port = uri.port > 0 ? uri.port : 8765;
      final key = uri.queryParameters['key'] ?? '';
      final name = uri.queryParameters['name'];
      if (host.isNotEmpty && key.isNotEmpty) {
        return ParsedPairingUri(host: host, port: port, apiKey: key, name: name);
      }
    } catch (_) {}
  }
  return null;
}

class ApiClient {
  final Dio _dio = Dio();
  String _baseUrl = "http://127.0.0.1:8765";
  String _apiKey = "";

  void updateConfig({required String host, required int port, required String apiKey}) {
    _baseUrl = "http://$host:$port";
    _apiKey = apiKey;
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 4);
    _dio.options.receiveTimeout = const Duration(seconds: 4);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
    };
  }

  /// Tests connectivity and API key validation against a specific host
  Future<ConnectionTestResult> testConnection({
    required String host,
    required int port,
    required String apiKey,
  }) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    final testDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );

    // 1. Test basic reachability
    try {
      final rootRes = await testDio.get('http://$host:$port/');
      if (rootRes.statusCode != 200) {
        return ConnectionTestResult(
          status: ConnectionTestStatus.unreachable,
          message: 'Server returned HTTP ${rootRes.statusCode}',
        );
      }
      final pcName = (rootRes.data is Map) ? (rootRes.data['hostname'] ?? 'Windows PC') : 'Windows PC';

      // 2. Test authentication
      try {
        final authRes = await testDio.get(
          'http://$host:$port/api/auth/verify',
          options: Options(headers: {'X-API-Key': apiKey}),
        );
        final latency = DateTime.now().millisecondsSinceEpoch - start;
        if (authRes.statusCode == 200) {
          return ConnectionTestResult(
            status: ConnectionTestStatus.success,
            hostname: pcName,
            latencyMs: latency,
            message: 'Connected to $pcName (${latency}ms)',
          );
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          return ConnectionTestResult(
            status: ConnectionTestStatus.invalidApiKey,
            hostname: pcName,
            message: 'PC found, but API Key is incorrect.',
          );
        } else if (dioErr.response?.statusCode == 429) {
          final retryAfter = dioErr.response?.headers.value('retry-after') ?? '60';
          return ConnectionTestResult(
            status: ConnectionTestStatus.invalidApiKey,
            hostname: pcName,
            message: 'Too many attempts. Host locked out this device for $retryAfter seconds. Restart host server or wait.',
          );
        }
      }
    } on DioException catch (e) {
      String msg = 'Could not reach PC at $host:$port.';
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        msg = 'Connection timed out. Ensure PC is on same Wi-Fi & Firewall allows port $port.';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Connection refused. Check that the PC Host Server is running and port is $port.';
      }
      return ConnectionTestResult(
        status: ConnectionTestStatus.unreachable,
        message: msg,
      );
    } catch (e) {
      return ConnectionTestResult(
        status: ConnectionTestStatus.unreachable,
        message: 'Network error: $e',
      );
    }

    return ConnectionTestResult(
      status: ConnectionTestStatus.unreachable,
      message: 'Unknown connection failure.',
    );
  }

  String getMediaThumbnailUrl() {
    return '$_baseUrl/api/media/thumbnail?api_key=$_apiKey';
  }

  // --- Telemetry ---
  Future<UnifiedTelemetryFrameModel?> getTelemetrySnapshot() async {
    try {
      final res = await _dio.get('/api/telemetry');
      if (res.statusCode == 200) {
        return UnifiedTelemetryFrameModel.fromJson(res.data);
      }
    } catch (_) {}
    return null;
  }

  // --- Audio ---
  Future<bool> setVolume(int volume) async {
    try {
      final res = await _dio.post('/api/audio/volume', data: {'volume': volume});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stepVolume(int step) async {
    try {
      final res = await _dio.post('/api/audio/step', data: {'step': step});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMute(bool mute) async {
    try {
      final res = await _dio.post('/api/audio/mute', data: {'mute': mute});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleMute() async {
    try {
      final res = await _dio.post('/api/audio/mute/toggle');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> switchAudioDevice(String deviceId) async {
    try {
      final res = await _dio.post('/api/audio/device', data: {'device_id': deviceId});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // --- Media ---
  Future<bool> controlMedia(String action, {int? positionMs}) async {
    try {
      final res = await _dio.post('/api/media/control', data: {
        'action': action,
        if (positionMs != null) 'position_ms': positionMs,
      });
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // --- Display ---
  Future<bool> setBrightness(int brightness) async {
    try {
      final res = await _dio.post('/api/display/brightness', data: {'brightness': brightness});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // --- Power ---
  Future<bool> executePowerAction(String action, {int delaySeconds = 0, bool force = false}) async {
    try {
      final res = await _dio.post('/api/power/action', data: {
        'action': action,
        'delay_seconds': delaySeconds,
        'force': force,
      });
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelPowerAction() async {
    try {
      final res = await _dio.post('/api/power/cancel');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // --- Apps ---
  Future<List<AppItemModel>> getApps() async {
    try {
      final res = await _dio.get('/api/apps');
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List).map((e) => AppItemModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> launchApp(String appId) async {
    try {
      final res = await _dio.post('/api/apps/launch/$appId');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<RunningTaskModel>> getTasks() async {
    try {
      final res = await _dio.get('/api/apps/tasks');
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List).map((e) => RunningTaskModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> killTask(int pid) async {
    try {
      final res = await _dio.post('/api/apps/tasks/$pid/kill');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // --- Extras ---
  Future<bool> setClipboard(String text) async {
    try {
      final res = await _dio.post('/api/extras/clipboard', data: {'text': text});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openUrl(String url) async {
    try {
      final res = await _dio.post('/api/extras/open-url', data: {'url': url.trim()});
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> showToast(String title, String message) async {
    try {
      final res = await _dio.post('/api/extras/toast', data: {
        'title': title,
        'message': message,
      });
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
  // --- Auth & Pairing ---
  Future<Map<String, dynamic>?> rotateApiKey() async {
    try {
      final res = await _dio.post('/api/auth/rotate-key');
      if (res.statusCode == 200 && res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPairingInfo() async {
    try {
      final res = await _dio.get('/api/auth/pairing-info');
      if (res.statusCode == 200) {
        return res.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

final apiClient = ApiClient();
