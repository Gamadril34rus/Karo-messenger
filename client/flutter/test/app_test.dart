import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/main.dart';

void main() {
  group('AppCharoApp', () {
    testWidgets('renders MaterialApp', (tester) async {
      await tester.pumpWidget(const AppCharoApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('has correct title', (tester) async {
      await tester.pumpWidget(const AppCharoApp());
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'ЧАРО');
    });
  });

  group('AppError', () {
    test('creates with message', () {
      const error = AppError(message: 'test error');
      expect(error.message, 'test error');
    });

    test('toString contains message', () {
      const error = AppError(message: 'test');
      expect(error.toString(), contains('test'));
    });
  });

  group('AppConstants', () {
    test('appName is ЧАРО', () {
      expect(AppConstants.appName, 'ЧАРО');
    });

    test('apiBaseUrl is not empty', () {
      expect(AppConstants.apiBaseUrl, isNotEmpty);
    });

    test('maxFileSize > 0', () {
      expect(AppConstants.maxFileSizeBytes, greaterThan(0));
    });

    test('chunkSize > 0', () {
      expect(AppConstants.chunkSize, greaterThan(0));
    });
  });

  group('HapticService', () {
    test('instance is singleton-like', () {
      final s1 = HapticService.instance;
      final s2 = HapticService.instance;
      expect(s1, same(s2));
    });
  });

  group('Logger', () {
    test('AppLogger is accessible', () {
      expect(AppLogger.instance, isNotNull);
    });
  });
}
