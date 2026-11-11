import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/pages/dashboard/dashboard_page_settings.dart';
import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/settings.dart';

class SettingsDashboardViewModel = DashboardPageViewModel
    with DashboardPageSettings;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late SettingsDashboardViewModel dashboardModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    preferences = await SharedPreferences.getInstance();

    dashboardModel = SettingsDashboardViewModel(
      preferences: preferences,
      version: '0.0.0.0',
    );
  });

  test('Toggle Grid', () async {
    await dashboardModel.toggleGrid(true);
    expect(preferences.getBool(PrefKeys.showGrid), true);

    await dashboardModel.toggleGrid(false);
    expect(preferences.getBool(PrefKeys.showGrid), false);
  });

  group('[Grid Size]:', () {
    setUp(() async {
      await preferences.setInt(PrefKeys.gridSize, 64);
    });

    test('Changing with null data does nothing', () async {
      dashboardModel.changeGridSize(null);

      expect(preferences.getInt(PrefKeys.gridSize), 64);
    });

    testWidgets('Pressing okay updates preference', (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardPage(model: dashboardModel)),
        ),
      );

      dashboardModel.changeGridSize('128');

      await widgetTester.pumpAndSettle();

      expect(find.text('Grid Resizing Warning'), findsOneWidget);

      final okayButton = find.widgetWithText(TextButton, 'Okay');

      expect(okayButton, findsOneWidget);
      await widgetTester.tap(okayButton);
      await widgetTester.pumpAndSettle();

      expect(preferences.getInt(PrefKeys.gridSize), 128);
    });

    testWidgets('Pressing cancel does nothing', (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardPage(model: dashboardModel)),
        ),
      );

      dashboardModel.changeGridSize('128');

      await widgetTester.pumpAndSettle();

      expect(find.text('Grid Resizing Warning'), findsOneWidget);

      final cancelButton = find.widgetWithText(TextButton, 'Cancel');

      expect(cancelButton, findsOneWidget);
      await widgetTester.tap(cancelButton);
      await widgetTester.pumpAndSettle();

      expect(preferences.getInt(PrefKeys.gridSize), 64);
    });
  });

  group('[Corner Radius]:', () {
    setUp(() async {
      await preferences.setDouble(PrefKeys.cornerRadius, 25);
    });

    test('Changing with null data does nothing', () async {
      await dashboardModel.changeCornerRadius(null);
      expect(preferences.getDouble(PrefKeys.cornerRadius), 25);
    });

    test('Changing with valid data', () async {
      await dashboardModel.changeCornerRadius('10');
      expect(preferences.getDouble(PrefKeys.cornerRadius), 10);
    });
  });

  test('Remember window position', () async {
    await preferences.setBool(PrefKeys.rememberWindowPosition, false);

    await dashboardModel.changeRememberWindowPosition(true);
    expect(preferences.getBool(PrefKeys.rememberWindowPosition), true);

    await dashboardModel.changeRememberWindowPosition(false);
    expect(preferences.getBool(PrefKeys.rememberWindowPosition), false);
  });

  group('[Log Level]:', () {
    setUp(() async {
      await preferences.setString(PrefKeys.logLevel, Level.info.levelName);
    });

    test('Setting to null (automatic) removes key', () async {
      await dashboardModel.changeLogLevel(null);

      expect(preferences.containsKey(PrefKeys.logLevel), isFalse);
    });

    test('Setting to trace', () async {
      await dashboardModel.changeLogLevel(Level.trace);

      expect(preferences.getString(PrefKeys.logLevel), 'Trace');
      expect(Logger.level, Level.trace);
    });
  });

  group('[DPI Override]:', () {
    setUp(() async {
      await preferences.setDouble(PrefKeys.gridDpiOverride, 1);
    });

    test('Setting to null does nothing', () async {
      await dashboardModel.changeGridDPI(null);

      expect(preferences.containsKey(PrefKeys.gridDpiOverride), isTrue);
      expect(preferences.getDouble(PrefKeys.gridDpiOverride), 1);
    });

    test('Setting to empty removes key', () async {
      await dashboardModel.changeGridDPI('');

      expect(preferences.containsKey(PrefKeys.gridDpiOverride), isFalse);
    });

    test('Setting to negative value does nothing', () async {
      await dashboardModel.changeGridDPI('-1');

      expect(preferences.getDouble(PrefKeys.gridDpiOverride), 1);
    });

    test('Setting to positive value', () async {
      await dashboardModel.changeGridDPI('1.25');

      expect(preferences.getDouble(PrefKeys.gridDpiOverride), 1.25);
    });
  });
}
