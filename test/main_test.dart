import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/main.dart';
import 'package:elastic_dashboard/services/settings.dart';

import 'test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full app test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    String filePath =
        '${Directory.current.path}/test_resources/test-layout.json';

    String jsonString = File(filePath).readAsStringSync();

    SharedPreferences.setMockInitialValues({PrefKeys.layout: jsonString});

    SharedPreferences preferences = await SharedPreferences.getInstance();

    await widgetTester.pumpWidget(
      Elastic(
        preferences: preferences,
        version: '0.0.0.0',
      ),
    );

    await widgetTester.pumpAndSettle();
  });
}
