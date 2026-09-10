import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../shared/widgets/glass_card.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  Future<void> _fetchAuditLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final settings = ref.read(settingsProvider);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      validateStatus: (status) => true,
    ));

    try {
      final res = await dio.get(
        'http://${settings.host}:${settings.port}/api/system/audit-log?limit=50',
        options: Options(headers: {
          'X-API-Key': settings.apiKey,
        }),
      );

      if (res.statusCode == 200) {
        final data = res.data is Map ? res.data : jsonDecode(res.data.toString());
        final rawEvents = data['events'] as List? ?? [];
        setState(() {
          _events = rawEvents.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load audit logs (HTTP ${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to PC: $e';
        _isLoading = false;
      });
    }
  }

  Color _getEventColor(String eventType) {
    if (eventType.contains('lockout') || eventType.contains('failed')) {
      return Colors.redAccent;
    } else if (eventType.contains('input')) {
      return AppColors.cyan;
    } else if (eventType.contains('telemetry')) {
      return Colors.greenAccent;
    } else if (eventType.contains('rotate')) {
      return Colors.amberAccent;
    } else if (eventType.contains('power')) {
      return Colors.purpleAccent;
    }
    return Colors.white70;
  }

  IconData _getEventIcon(String eventType) {
    if (eventType.contains('lockout')) return Icons.gpp_bad_rounded;
    if (eventType.contains('failed')) return Icons.lock_clock_rounded;
    if (eventType.contains('input')) return Icons.mouse_rounded;
    if (eventType.contains('telemetry')) return Icons.stream_rounded;
    if (eventType.contains('rotate')) return Icons.key_rounded;
    if (eventType.contains('power')) return Icons.power_settings_new_rounded;
    if (eventType.contains('disconnected')) return Icons.link_off_rounded;
    return Icons.security_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PC Security Audit Log'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Log',
            onPressed: _isLoading ? null : _fetchAuditLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchAuditLogs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Text(
                        'No audit events recorded yet.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final ev = _events[index];
                        final eventType = ev['event'] as String? ?? 'unknown';
                        final clientIp = ev['client_ip'] as String? ?? '127.0.0.1';
                        final rawTs = ev['timestamp'] as String? ?? '';
                        final ts = rawTs.length >= 19 ? rawTs.substring(0, 19).replaceAll('T', ' ') : rawTs;
                        final color = _getEventColor(eventType);
                        final icon = _getEventIcon(eventType);
                        final details = ev['details'] as Map? ?? {};

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            eventType.replaceAll('_', ' ').toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                          Text(
                                            ts,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Client: $clientIp',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.8),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      if (details.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          details.toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
