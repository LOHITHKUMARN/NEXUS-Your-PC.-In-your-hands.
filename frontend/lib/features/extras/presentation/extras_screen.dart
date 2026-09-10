import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/glass_card.dart';
import 'package:pc_control_center/shared/widgets/pc_action_button.dart';
import 'package:pc_control_center/shared/widgets/pc_icon_badge.dart';

class ExtrasScreen extends ConsumerStatefulWidget {
  const ExtrasScreen({super.key});

  @override
  ConsumerState<ExtrasScreen> createState() => _ExtrasScreenState();
}

class _ExtrasScreenState extends ConsumerState<ExtrasScreen> {
  final _clipboardCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _toastTitleCtrl = TextEditingController(text: 'PC Control Center');
  final _toastMsgCtrl = TextEditingController();

  @override
  void dispose() {
    _clipboardCtrl.dispose();
    _urlCtrl.dispose();
    _toastTitleCtrl.dispose();
    _toastMsgCtrl.dispose();
    super.dispose();
  }

  void _handleOpenUrl() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) return;

    final uri = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    await ref.read(extrasControllerProvider).openUrl(uri);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening $uri on PC...')),
      );
    }
  }

  Widget _quickUrlChip(String label, String url, bool isConnected) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isConnected ? Colors.white : AppColors.metricNormal,
        ),
      ),
      backgroundColor: AppColors.buttonSurface,
      side: const BorderSide(color: AppColors.buttonBorder, width: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: isConnected
          ? () {
              _urlCtrl.text = url;
              _handleOpenUrl();
            }
          : null,
    );
  }

  Widget _buildCategoryHeader(IconData icon, String title) {
    return Row(
      children: [
        PcIconBadge(icon: icon, size: 32, iconSize: 16),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final extras = ref.read(extrasControllerProvider);
    final connectionStatus = ref.watch(connectionStatusProvider).value ?? ConnectionStatus.disconnected;
    final isConnected = connectionStatus == ConnectionStatus.connected;

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 88),
      children: [
        // Offline Warning Banner when Disconnected
        if (!isConnected)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warningAmber.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warningAmber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PC is offline. Reconnect to execute sync actions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warningAmber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 1. Send Clipboard Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.content_paste_go_rounded, 'Push Text to PC Clipboard'),
              const SizedBox(height: 10),
              TextField(
                controller: _clipboardCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type or paste text to send to your PC clipboard...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PcActionButton(
                  label: 'Send to Clipboard',
                  icon: Icons.send_rounded,
                  onPressed: isConnected
                      ? () async {
                          if (_clipboardCtrl.text.isNotEmpty) {
                            await extras.setClipboard(_clipboardCtrl.text);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Text pushed to PC clipboard!')),
                              );
                              _clipboardCtrl.clear();
                            }
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Open URL on PC
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.open_in_browser_rounded, 'Open Web Link on PC'),
              const SizedBox(height: 10),
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                textInputAction: TextInputAction.go,
                onSubmitted: isConnected ? (_) => _handleOpenUrl() : null,
                decoration: InputDecoration(
                  hintText: 'e.g. youtube.com, github.com',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white38),
                    onPressed: () => _urlCtrl.clear(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _quickUrlChip('YouTube', 'https://youtube.com', isConnected),
                  _quickUrlChip('GitHub', 'https://github.com', isConnected),
                  _quickUrlChip('Google', 'https://google.com', isConnected),
                  _quickUrlChip('ChatGPT', 'https://chatgpt.com', isConnected),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PcActionButton(
                  label: 'Open on PC Browser',
                  icon: Icons.launch_rounded,
                  onPressed: isConnected ? _handleOpenUrl : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Send Toast Notification
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.notifications_active_outlined, 'Send Toast Notification to PC'),
              const SizedBox(height: 10),
              TextField(
                controller: _toastTitleCtrl,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notification Title',
                  labelStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _toastMsgCtrl,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Message Body',
                  labelStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PcActionButton(
                  label: 'Show Toast Alert',
                  icon: Icons.notifications_none_rounded,
                  onPressed: isConnected
                      ? () async {
                          await extras.showToast(_toastTitleCtrl.text, _toastMsgCtrl.text);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Toast sent to Windows!')),
                            );
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
