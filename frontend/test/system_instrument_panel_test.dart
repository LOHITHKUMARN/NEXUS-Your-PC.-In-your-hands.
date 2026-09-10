import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/dashboard/presentation/system_instrument_panel.dart';

void main() {
  group('SystemInstrumentPanel Tests', () {
    final mockSystem = SystemTelemetryModel(
      cpuPercent: 8.0,
      cpuFreqMhz: 1805.0,
      cpuCoresPercent: [8.0, 7.5],
      ramPercent: 85.0,
      ramUsedGb: 6.2,
      ramTotalGb: 7.3,
      disks: [
        DiskInfoModel(mount: 'C:', totalGb: 500, usedGb: 250, freeGb: 250, percent: 50.0),
      ],
      network: NetworkRateModel(
        downloadKbps: 120.0,
        uploadKbps: 45.0,
        totalDownloadMb: 1024.0,
        totalUploadMb: 256.0,
      ),
      gpu: GpuInfoModel(
        available: true,
        name: 'NVIDIA GeForce RTX',
        loadPercent: 0.0,
        temperatureC: 40.0,
      ),
      battery: BatteryInfoModel(present: true, percent: 65, powerPlugged: true),
      hostname: 'DESKTOP-QNHI8OS',
      uptimeSeconds: 3600,
    );

    test('Semantic color mapping rule functions accurately', () {
      expect(AppColors.getMetricColor(5.0), AppColors.metricNormal);
      expect(AppColors.getMetricColor(79.9), AppColors.metricNormal);
      expect(AppColors.getMetricColor(80.0), AppColors.warningAmber);
      expect(AppColors.getMetricColor(85.0), AppColors.warningAmber);
      expect(AppColors.getMetricColor(90.0), AppColors.criticalRed);
      expect(AppColors.getMetricColor(99.0), AppColors.criticalRed);
    });

    testWidgets('Renders all dials, header, and network strip', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SystemInstrumentPanel(system: mockSystem),
          ),
        ),
      );

      // Header
      expect(find.text('SYSTEM MONITOR'), findsOneWidget);
      expect(find.text('HIGH LOAD'), findsOneWidget); // Since RAM is 85%

      // Dials labels and values
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('8%'), findsOneWidget);
      expect(find.text('1805 MHz'), findsOneWidget);

      expect(find.text('RAM'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('6.2 / 7.3 GB'), findsOneWidget);

      expect(find.text('GPU'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('40°C'), findsOneWidget);

      // Network
      expect(find.text('NET'), findsOneWidget);
      expect(find.text('120K/s'), findsOneWidget);
      expect(find.text('45K/s'), findsOneWidget);
    });
  });
}
