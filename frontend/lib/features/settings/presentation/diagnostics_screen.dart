import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../shared/widgets/glass_card.dart';

enum DiagnosticStatus { pending, running, success, failed }

class DiagnosticStep {
  final String title;
  final String description;
  DiagnosticStatus status;
  String? resultMessage;
  int? latencyMs;

  DiagnosticStep({
    required this.title,
    required this.description,
    this.status = DiagnosticStatus.pending,
    this.resultMessage,
    this.latencyMs,
  });
}

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _isRunning = false;
  String? _detectedMac;

  final List<DiagnosticStep> _steps = [
    DiagnosticStep(
      title: '1. LAN Reachability & Discovery',
      description: 'Pings host endpoint (GET /api/discovery/info) and checks port connectivity.',
    ),
    DiagnosticStep(
      title: '2. API Key Authentication',
      description: 'Tests pre-shared token security against REST telemetry endpoint.',
    ),
    DiagnosticStep(
      title: '3. Telemetry Stream (500ms)',
      description: 'Tests WebSocket handshake (/api/telemetry/ws) and live frame reception.',
    ),
    DiagnosticStep(
      title: '4. Input Control Stream (Sub-20ms)',
      description: 'Verifies SendInput worker responsiveness via zero-displacement probe.',
    ),
  ];

  Future<void> _runDiagnostics() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      for (final s in _steps) {
        s.status = DiagnosticStatus.pending;
        s.resultMessage = null;
        s.latencyMs = null;
      }
    });

    final settings = ref.read(settingsProvider);
    final host = settings.host;
    final port = settings.port;
    final apiKey = settings.apiKey;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      validateStatus: (status) => true,
    ));

    // STEP 1: LAN Reachability
    setState(() => _steps[0].status = DiagnosticStatus.running);
    final s1Watch = Stopwatch()..start();
    try {
      final res = await dio.get('http://$host:$port/api/discovery/info');
      s1Watch.stop();

      if (res.statusCode == 200) {
        final data = res.data is Map ? res.data : jsonDecode(res.data.toString());
        final hostname = data['hostname'] ?? 'PC';
        final version = data['version'] ?? 'Unknown';
        final mac = data['mac_address'];
        if (mac != null && mac.toString().isNotEmpty) {
          _detectedMac = mac.toString();
        }
        _steps[0].status = DiagnosticStatus.success;
        _steps[0].latencyMs = s1Watch.elapsedMilliseconds;
        _steps[0].resultMessage = 'Connected to $hostname (v$version) in ${s1Watch.elapsedMilliseconds}ms.';
      } else {
        _steps[0].status = DiagnosticStatus.failed;
        _steps[0].resultMessage = 'Server returned HTTP ${res.statusCode}.';
      }
    } catch (e) {
      s1Watch.stop();
      _steps[0].status = DiagnosticStatus.failed;
      if (e.toString().contains('Connection refused') || e.toString().contains('Failed host lookup')) {
        _steps[0].resultMessage = 'Connection refused. Ensure backend is running and Windows Firewall allows port $port.';
      } else {
        _steps[0].resultMessage = 'Failed to reach PC: $e';
      }
    }
    setState(() {});

    // If Step 1 failed, stop early
    if (_steps[0].status == DiagnosticStatus.failed) {
      setState(() => _isRunning = false);
      return;
    }

    // STEP 2: API Key Auth
    setState(() => _steps[1].status = DiagnosticStatus.running);
    final s2Watch = Stopwatch()..start();
    try {
      final res = await dio.get(
        'http://$host:$port/api/telemetry',
        options: Options(headers: {'X-API-Key': apiKey}),
      );
      s2Watch.stop();

      if (res.statusCode == 200) {
        _steps[1].status = DiagnosticStatus.success;
        _steps[1].latencyMs = s2Watch.elapsedMilliseconds;
        _steps[1].resultMessage = 'API Key valid. Authenticated successfully.';
      } else if (res.statusCode == 401) {
        _steps[1].status = DiagnosticStatus.failed;
        _steps[1].resultMessage = '401 Unauthorized: API Key mismatch. Check key in Settings.';
      } else if (res.statusCode == 429) {
        _steps[1].status = DiagnosticStatus.failed;
        _steps[1].resultMessage = '429 Locked Out: Too many invalid auth attempts. Wait 5 minutes.';
      } else {
        _steps[1].status = DiagnosticStatus.failed;
        _steps[1].resultMessage = 'Auth check returned HTTP ${res.statusCode}.';
      }
    } catch (e) {
      s2Watch.stop();
      _steps[1].status = DiagnosticStatus.failed;
      _steps[1].resultMessage = 'Auth test failed: $e';
    }
    setState(() {});

    if (_steps[1].status == DiagnosticStatus.failed) {
      setState(() => _isRunning = false);
      return;
    }

    // STEP 3: Telemetry WebSocket Stream
    setState(() => _steps[2].status = DiagnosticStatus.running);
    final s3Watch = Stopwatch()..start();
    WebSocketChannel? telemChannel;
    try {
      final telemUri = Uri.parse('ws://$host:$port/api/telemetry/ws?api_key=$apiKey');
      telemChannel = WebSocketChannel.connect(telemUri);

      final completer = Completer<bool>();
      final sub = telemChannel.stream.listen(
        (data) {
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (err) {
          if (!completer.isCompleted) completer.completeError(err);
        },
      );

      await completer.future.timeout(const Duration(seconds: 5));
      s3Watch.stop();
      await sub.cancel();
      telemChannel.sink.close();

      _steps[2].status = DiagnosticStatus.success;
      _steps[2].latencyMs = s3Watch.elapsedMilliseconds;
      _steps[2].resultMessage = 'Telemetry stream active (first frame in ${s3Watch.elapsedMilliseconds}ms).';
    } catch (e) {
      s3Watch.stop();
      _steps[2].status = DiagnosticStatus.failed;
      _steps[2].resultMessage = 'Telemetry socket failed: $e';
    } finally {
      try {
        telemChannel?.sink.close();
      } catch (_) {}
    }
    setState(() {});

    // STEP 4: Input Control WebSocket Stream (Safe, Zero-Move Probe)
    setState(() => _steps[3].status = DiagnosticStatus.running);
    final s4Watch = Stopwatch()..start();
    WebSocketChannel? inputChannel;
    try {
      final inputUri = Uri.parse('ws://$host:$port/api/input/ws?api_key=$apiKey');
      inputChannel = WebSocketChannel.connect(inputUri);

      final pongCompleter = Completer<bool>();
      final sub = inputChannel.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data);
            if (parsed['t'] == 'pong') {
              if (!pongCompleter.isCompleted) pongCompleter.complete(true);
            }
          } catch (_) {}
        },
        onError: (err) {
          if (!pongCompleter.isCompleted) pongCompleter.completeError(err);
        },
      );

      // Send harmless ping probe — zero cursor motion!
      inputChannel.sink.add(jsonEncode({'t': 'ping'}));

      await pongCompleter.future.timeout(const Duration(seconds: 4));
      s4Watch.stop();
      await sub.cancel();
      inputChannel.sink.close();

      _steps[3].status = DiagnosticStatus.success;
      _steps[3].latencyMs = s4Watch.elapsedMilliseconds;
      _steps[3].resultMessage = 'Input channel active (probe ping-pong in ${s4Watch.elapsedMilliseconds}ms). Zero cursor displacement.';
    } catch (e) {
      s4Watch.stop();
      _steps[3].status = DiagnosticStatus.failed;
      _steps[3].resultMessage = 'Input socket failed: $e';
    } finally {
      try {
        inputChannel?.sink.close();
      } catch (_) {}
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final allDone = _steps.every((s) => s.status == DiagnosticStatus.success);
    final hasFailed = _steps.any((s) => s.status == DiagnosticStatus.failed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Diagnostics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded, color: AppColors.cyan, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Self-Diagnostic Engine',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target: ${settings.host}:${settings.port}',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                          ),
                          if (_detectedMac != null)
                            Text(
                              'MAC: $_detectedMac',
                              style: const TextStyle(fontSize: 11, color: AppColors.cyan, fontFamily: 'monospace'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runDiagnostics,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.play_arrow_rounded, color: Colors.black),
                    label: Text(
                      _isRunning ? 'Running Diagnostic Tests...' : 'Run "Test My Setup"',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status Summary Badge
          if (allDone)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All Systems Operational — LAN, Auth, Telemetry, and Trackpad channels ready!',
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (hasFailed)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Setup Issues Detected. Review the failed step below for troubleshooting advice.',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (allDone || hasFailed) const SizedBox(height: 16),

          // Diagnostic Steps List
          ..._steps.map((step) => _buildStepCard(step)),
        ],
      ),
    );
  }

  Widget _buildStepCard(DiagnosticStep step) {
    Color iconColor;
    Widget statusWidget;

    switch (step.status) {
      case DiagnosticStatus.pending:
        iconColor = Colors.white30;
        statusWidget = const Text('PENDING', style: TextStyle(fontSize: 11, color: Colors.white38));
        break;
      case DiagnosticStatus.running:
        iconColor = AppColors.cyan;
        statusWidget = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
        );
        break;
      case DiagnosticStatus.success:
        iconColor = Colors.greenAccent;
        statusWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (step.latencyMs != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${step.latencyMs}ms',
                  style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ),
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
          ],
        );
        break;
      case DiagnosticStatus.failed:
        iconColor = Colors.redAccent;
        statusWidget = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  step.status == DiagnosticStatus.success
                      ? Icons.check_circle_outline
                      : step.status == DiagnosticStatus.failed
                          ? Icons.error_outline
                          : Icons.radio_button_unchecked,
                  color: iconColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: step.status == DiagnosticStatus.failed ? Colors.redAccent : Colors.white,
                    ),
                  ),
                ),
                statusWidget,
              ],
            ),
            const SizedBox(height: 6),
            Text(
              step.description,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55)),
            ),
            if (step.resultMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: step.status == DiagnosticStatus.failed
                      ? Colors.redAccent.withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: step.status == DiagnosticStatus.failed
                        ? Colors.redAccent.withOpacity(0.4)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      step.status == DiagnosticStatus.failed ? Icons.info_outline : Icons.check,
                      size: 15,
                      color: step.status == DiagnosticStatus.failed ? Colors.redAccent : Colors.greenAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.resultMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: step.status == DiagnosticStatus.failed ? Colors.redAccent : Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
