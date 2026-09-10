import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class WakeOnLanService {
  /// Parses a MAC address string into 6 raw bytes.
  /// Accepts formats: 'AA:BB:CC:DD:EE:FF', 'AA-BB-CC-DD-EE-FF', or 'AABBCCDDEEFF'.
  static Uint8List parseMacAddress(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.length != 12) {
      throw FormatException('Invalid MAC address: $mac (must contain 12 hex digits)');
    }

    final bytes = Uint8List(6);
    for (int i = 0; i < 6; i++) {
      bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Generates standard Wake-on-LAN Magic Packet:
  /// 6 bytes of 0xFF followed by 16 repetitions of the target 6-byte MAC address (102 bytes total).
  static Uint8List createMagicPacket(String macAddress) {
    final macBytes = parseMacAddress(macAddress);
    final packet = Uint8List(102);

    // First 6 bytes: 0xFF
    for (int i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }

    // Next 16 * 6 bytes: target MAC repeated 16 times
    for (int i = 0; i < 16; i++) {
      packet.setRange(6 + i * 6, 6 + (i + 1) * 6, macBytes);
    }

    return packet;
  }

  /// Calculates the subnet-directed broadcast address from an IPv4 host address.
  /// E.g. '192.168.29.249' -> '192.168.29.255'.
  static String calculateSubnetBroadcast(String hostIp) {
    final parts = hostIp.trim().split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    }
    return '255.255.255.255';
  }

  /// Broadcasts the Magic Packet via UDP to both 255.255.255.255:port and subnet broadcast.
  static Future<bool> sendWakeOnLan({
    required String macAddress,
    required String hostIp,
    int port = 9,
  }) async {
    try {
      final packet = createMagicPacket(macAddress);
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // 1. Global broadcast: 255.255.255.255
      try {
        final globalTarget = InternetAddress('255.255.255.255');
        socket.send(packet, globalTarget, port);
        debugPrint('WoL packet sent to 255.255.255.255:$port');
      } catch (e) {
        debugPrint('Global WoL broadcast note: $e');
      }

      // 2. Subnet-directed broadcast (e.g. 192.168.29.255)
      try {
        final subnetIp = calculateSubnetBroadcast(hostIp);
        if (subnetIp != '255.255.255.255') {
          final subnetTarget = InternetAddress(subnetIp);
          socket.send(packet, subnetTarget, port);
          debugPrint('WoL packet sent to subnet-directed broadcast $subnetIp:$port');
        }
      } catch (e) {
        debugPrint('Subnet WoL broadcast note: $e');
      }

      socket.close();
      return true;
    } catch (e) {
      debugPrint('Failed to broadcast Wake-on-LAN packet: $e');
      return false;
    }
  }
}
