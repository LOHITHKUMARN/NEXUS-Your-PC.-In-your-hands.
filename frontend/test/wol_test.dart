import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/network/wol_service.dart';

void main() {
  group('WakeOnLanService Tests', () {
    test('parseMacAddress parses valid colon-separated MAC', () {
      final bytes = WakeOnLanService.parseMacAddress('CC:5E:F8:53:56:3F');
      expect(bytes.length, 6);
      expect(bytes[0], 0xCC);
      expect(bytes[1], 0x5E);
      expect(bytes[2], 0xF8);
      expect(bytes[3], 0x53);
      expect(bytes[4], 0x56);
      expect(bytes[5], 0x3F);
    });

    test('parseMacAddress parses dash-separated and unseparated MAC', () {
      final dashBytes = WakeOnLanService.parseMacAddress('AA-BB-CC-DD-EE-FF');
      expect(dashBytes, equals([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]));

      final rawBytes = WakeOnLanService.parseMacAddress('aabbccddeeff');
      expect(rawBytes, equals([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]));
    });

    test('parseMacAddress throws on invalid length', () {
      expect(
        () => WakeOnLanService.parseMacAddress('12:34:56'),
        throwsA(isA<FormatException>()),
      );
    });

    test('createMagicPacket constructs exact 102-byte frame', () {
      final packet = WakeOnLanService.createMagicPacket('AA:BB:CC:DD:EE:FF');
      expect(packet.length, 102);

      // Header: 6 bytes of 0xFF
      for (int i = 0; i < 6; i++) {
        expect(packet[i], 0xFF);
      }

      // Body: 16 repetitions of [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
      final expectedMac = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF];
      for (int rep = 0; rep < 16; rep++) {
        final start = 6 + rep * 6;
        final slice = packet.sublist(start, start + 6);
        expect(slice, equals(expectedMac));
      }
    });

    test('calculateSubnetBroadcast handles standard IPv4 addresses', () {
      expect(
        WakeOnLanService.calculateSubnetBroadcast('192.168.29.249'),
        '192.168.29.255',
      );
      expect(
        WakeOnLanService.calculateSubnetBroadcast('10.0.0.15'),
        '10.0.0.255',
      );
      expect(
        WakeOnLanService.calculateSubnetBroadcast('invalid-host'),
        '255.255.255.255',
      );
    });
  });
}
