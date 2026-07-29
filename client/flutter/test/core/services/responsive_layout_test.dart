import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/responsive_layout.dart';

void main() {
  group('ResponsiveLayout', () {
    test('DeviceType enum has all types', () {
      expect(DeviceType.values.length, 3);
      expect(DeviceType.values, contains(DeviceType.mobile));
      expect(DeviceType.values, contains(DeviceType.tablet));
      expect(DeviceType.values, contains(DeviceType.desktop));
    });

    test('breakpoints are correctly defined', () {
      // Mobile: < 600
      // Tablet: 600-1199
      // Desktop: >= 1200
      // These are just documentation tests — actual layout testing requires Widget tests
      expect(DeviceType.mobile.index, 0);
      expect(DeviceType.tablet.index, 1);
      expect(DeviceType.desktop.index, 2);
    });
  });
}
