import 'dart:async';
import 'package:dio/dio.dart';

class DiscoveredHost {
  final String ip;
  final int port;
  final String hostname;
  final String serviceName;
  final int latencyMs;

  DiscoveredHost({
    required this.ip,
    required this.port,
    required this.hostname,
    required this.serviceName,
    required this.latencyMs,
  });
}

class DiscoveryService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 600),
      receiveTimeout: const Duration(milliseconds: 600),
    ),
  );

  /// Scans the local network subnet and common IPs for PC Control Center host.
  Stream<DiscoveredHost> scanSubnetStream({
    String? baseSubnet,
    int port = 8765,
  }) async* {
    final Set<String> candidates = {};

    // 1. Common local loopback and emulator endpoints
    candidates.add("127.0.0.1");
    candidates.add("10.0.2.2"); // Android emulator host alias
    candidates.add("localhost");

    // 2. Extract base subnet if provided, or scan common subnets
    final List<String> subnets = [];
    if (baseSubnet != null && baseSubnet.isNotEmpty) {
      final parts = baseSubnet.split('.');
      if (parts.length >= 3) {
        subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }

    // Add standard domestic Wi-Fi subnets
    for (final s in ['192.168.29', '192.168.1', '192.168.0', '192.168.137', '172.20.10', '10.0.0']) {
      if (!subnets.contains(s)) {
        subnets.add(s);
      }
    }

    // First, yield immediate check for candidate loopbacks
    for (final ip in candidates) {
      final host = await _probeHost(ip, port);
      if (host != null) yield host;
    }

    // Probe subnets in parallel batches of 25 IPs for rapid discovery
    for (final subnet in subnets) {
      for (int i = 1; i <= 254; i += 25) {
        final end = (i + 24).clamp(1, 254);
        final batch = <Future<DiscoveredHost?>>[];
        for (int j = i; j <= end; j++) {
          final targetIp = '$subnet.$j';
          batch.add(_probeHost(targetIp, port));
        }

        final results = await Future.wait(batch);
        for (final host in results) {
          if (host != null) {
            yield host;
          }
        }
      }
    }
  }

  Future<DiscoveredHost?> _probeHost(String ip, int port) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await _dio.get('http://$ip:$port/');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        if (data['service'] == 'PC Control Center' || data['status'] == 'online') {
          final latency = DateTime.now().millisecondsSinceEpoch - start;
          return DiscoveredHost(
            ip: ip,
            port: port,
            hostname: data['hostname'] ?? 'Windows PC',
            serviceName: data['service'] ?? 'PC Control Center',
            latencyMs: latency,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}

final discoveryService = DiscoveryService();
