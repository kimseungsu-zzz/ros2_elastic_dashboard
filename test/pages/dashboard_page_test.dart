import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titlebar_buttons/titlebar_buttons.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

import '../test_util.dart';

Future<void> pumpDashboardPage(
  WidgetTester widgetTester,
  SharedPreferences preferences, {
  UpdateChecker? updateChecker,
  Size? size = const Size(1920, 1080),
}) async {
  FlutterError.onError = ignoreOverflowErrors;
  if (size != null) {
    widgetTester.view.physicalSize = size;
    widgetTester.view.devicePixelRatio = 1.0;
  }

  await widgetTester.pumpWidget(
    MaterialApp(
      home: DashboardPage(
        model: DashboardPageViewModelImpl(
          preferences: preferences,
          version: '0.0.0.0',
          updateChecker: updateChecker ?? createMockUpdateChecker(),
        ),
      ),
    ),
  );

  await widgetTester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String jsonFilePath =
      '${Directory.current.path}/test_resources/test-layout.json';

  late String jsonString;

  late SharedPreferences preferences;

  setUpAll(() async {
    jsonString = jsonEncode(jsonDecode(File(jsonFilePath).readAsStringSync()));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.layout: jsonString,
    });

    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() {
    hotKeyManager.tearDown();
  });

  group('[Responsive Layout]:', () {
    final fileButton = find.widgetWithText(SubmenuButton, 'File');
    final collapsedMenu = find.widgetWithIcon(SubmenuButton, Icons.menu);
    final title = find.text('Elastic');

    testWidgets('Shows everything on normal screen', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(fileButton, findsOneWidget);
      expect(collapsedMenu, findsNothing);
      expect(title, findsOneWidget);
      expect(find.text('ROS 2 Graph'), findsOneWidget);
    });

    testWidgets('Hides title when width = 525', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        size: const Size(525, 525),
      );

      expect(title, findsNothing);
    });

    testWidgets('Collapses menu when width < 460', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        size: const Size(459.99, 459.99),
      );

      expect(fileButton, findsNothing);
      expect(collapsedMenu, findsOneWidget);
      expect(title, findsNothing);
    });
  });

  testWidgets('About dialog', (widgetTester) async {
    await pumpDashboardPage(widgetTester, preferences);

    final helpButton = find.widgetWithText(SubmenuButton, 'Help');

    expect(helpButton, findsOneWidget);

    await widgetTester.tap(helpButton);
    await widgetTester.pumpAndSettle();

    final showAboutDialogButton = find.widgetWithText(MenuItemButton, 'About');

    expect(showAboutDialogButton, findsOneWidget);

    await widgetTester.tap(showAboutDialogButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AboutDialog), findsOneWidget);
  });

  group('[Tab Manipulation]:', () {
    testWidgets('Changing tabs', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.text('Second ROS Viewer'), findsNothing);

      expect(find.byType(EditableTabBar), findsOneWidget);

      final autonomousTab = find.widgetWithText(
        AnimatedContainer,
        'Autonomous',
      );

      expect(autonomousTab, findsOneWidget);

      await widgetTester.tap(autonomousTab);
      await widgetTester.pumpAndSettle();

      expect(find.text('Second ROS Viewer'), findsOneWidget);
    });

    testWidgets('Creating new tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      expect(find.byType(EditableTabBar), findsOneWidget);

      final createNewTabButton = find.descendant(
        of: find.byType(EditableTabBar),
        matching: find.byIcon(Icons.add),
      );

      expect(createNewTabButton, findsOneWidget);

      await widgetTester.tap(createNewTabButton);
      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(3));
    });

    testWidgets('Creating new tab (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyT);

      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(3));
    });

    testWidgets('Closing tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      expect(find.byType(EditableTabBar), findsOneWidget);

      final closeTabButton = find
          .descendant(
            of: find.byType(EditableTabBar),
            matching: find.byIcon(Icons.close),
          )
          .last;

      expect(closeTabButton, findsOneWidget);

      await widgetTester.tap(closeTabButton);
      await widgetTester.pumpAndSettle();

      expect(
        find.text('Confirm Tab Close', skipOffstage: false),
        findsOneWidget,
      );

      final confirmButton = find.widgetWithText(
        TextButton,
        'OK',
        skipOffstage: false,
      );

      expect(confirmButton, findsOneWidget);

      await widgetTester.tap(confirmButton);
      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(1));
    });

    testWidgets('Closing tab (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyW);

      await widgetTester.pumpAndSettle();

      expect(
        find.text('Confirm Tab Close', skipOffstage: false),
        findsOneWidget,
      );

      final confirmButton = find.widgetWithText(
        TextButton,
        'OK',
        skipOffstage: false,
      );

      expect(confirmButton, findsOneWidget);

      await widgetTester.tap(confirmButton);
      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(1));
    });

    testWidgets('Reordering tabs', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      final tabLeftButton = find.descendant(
        of: editableTabBar,
        matching: find.byIcon(Icons.west),
      );
      final tabRightButton = find.descendant(
        of: editableTabBar,
        matching: find.byIcon(Icons.east),
      );

      expect(tabLeftButton, findsOneWidget);
      expect(tabRightButton, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.tap(tabLeftButton);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should not change since index is 0',
      );

      await widgetTester.tap(tabRightButton);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 1);

      await widgetTester.tap(tabRightButton);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should not change since index is equal to number of tabs',
      );

      await widgetTester.tap(tabLeftButton);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 0);
    });

    testWidgets('Reordering tabs (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should not change since index is 0',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 1);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should not change since index is equal to number of tabs',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 0);
    });

    testWidgets('Navigate tabs left right (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.shift);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should roll over',
      );

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should roll back over to 0',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should increase to 1 (no rollover)',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 0);
    });

    testWidgets('Navigate to specific tabs', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should remain at 0',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 1);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.digit5);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.digit5);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should remain at 1 since there is no tab at index 4',
      );
    });

    testWidgets('Renaming tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final teleopTab = find.widgetWithText(AnimatedContainer, 'Teleoperated');

      expect(teleopTab, findsOneWidget);

      await widgetTester.tap(teleopTab, buttons: kSecondaryButton);
      await widgetTester.pumpAndSettle();

      final renameButton = find.text('Rename');

      expect(renameButton, findsOneWidget);

      await widgetTester.tap(renameButton);
      await widgetTester.pumpAndSettle();

      expect(find.text('Rename Tab'), findsOneWidget);

      final nameTextField = find.widgetWithText(DialogTextInput, 'Name');

      expect(nameTextField, findsOneWidget);

      await widgetTester.enterText(nameTextField, 'New Tab Name!');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      final saveButton = find.widgetWithText(TextButton, 'Save');

      expect(saveButton, findsOneWidget);

      await widgetTester.tap(saveButton);
      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(AnimatedContainer, 'Teleoperated'),
        findsNothing,
      );
      expect(
        find.widgetWithText(AnimatedContainer, 'New Tab Name!'),
        findsOneWidget,
      );
    });

    testWidgets('Duplicating tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final teleopTab = find.widgetWithText(AnimatedContainer, 'Teleoperated');

      expect(teleopTab, findsOneWidget);

      await widgetTester.tap(teleopTab, buttons: kSecondaryButton);
      await widgetTester.pumpAndSettle();

      final duplicateButton = find.text('Duplicate');

      expect(duplicateButton, findsOneWidget);

      await widgetTester.tap(duplicateButton);
      await widgetTester.pumpAndSettle();

      expect(find.text('Teleoperated (Copy)'), findsOneWidget);
    });
  });

  group('[Window Manipulation]:', () {
    testWidgets('Minimizing window', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final minimizeButton = find.ancestor(
        of: find.byType(DecoratedMinimizeButton),
        matching: find.byType(InkWell),
      );

      expect(minimizeButton, findsOneWidget);

      await widgetTester.tap(minimizeButton);
    });

    testWidgets('Maximizing/unmaximizing window', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final appBar = find.byType(CustomAppBar);

      expect(appBar, findsOneWidget);

      await widgetTester.tapAt(const Offset(250, 0));
      await widgetTester.pump(kDoubleTapMinTime);
      await widgetTester.tapAt(const Offset(250, 0));

      await widgetTester.pumpAndSettle();

      final maximizeButton = find.ancestor(
        of: find.byType(DecoratedMaximizeButton),
        matching: find.byType(InkWell),
      );

      await widgetTester.tap(maximizeButton);
    });

    testWidgets('Closing window (All changes saved)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final rosWidget = find.widgetWithText(WidgetContainer, 'Test ROS Viewer');

      expect(rosWidget, findsOneWidget);

      // Drag to a location
      await widgetTester.drag(rosWidget, const Offset(256, -128));
      await widgetTester.pumpAndSettle();

      // Drag back to its original location
      await widgetTester.drag(rosWidget, const Offset(-256, 128));
      await widgetTester.pumpAndSettle();

      final closeButton = find.ancestor(
        of: find.byType(DecoratedCloseButton),
        matching: find.byType(InkWell),
      );

      await widgetTester.tap(closeButton);
      await widgetTester.pumpAndSettle();

      expect(find.widgetWithText(AlertDialog, 'Unsaved Changes'), findsNothing);
    });

    testWidgets('Closing window (Unsaved changes)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final rosWidget = find.widgetWithText(WidgetContainer, 'Test ROS Viewer');

      expect(rosWidget, findsOneWidget);

      // Drag to a location
      await widgetTester.drag(rosWidget, const Offset(256, -128));

      await widgetTester.pumpAndSettle();

      final closeButton = find.ancestor(
        of: find.byType(DecoratedCloseButton),
        matching: find.byType(InkWell),
      );

      expect(closeButton, findsOneWidget);

      await widgetTester.tap(closeButton);
      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(AlertDialog, 'Unsaved Changes'),
        findsOneWidget,
      );

      final discardButton = find.widgetWithText(TextButton, 'Discard');

      expect(discardButton, findsOneWidget);

      await widgetTester.tap(discardButton);
      await widgetTester.pumpAndSettle();
    });
  });

  group('[Misc Shortcuts]:', () {
    testWidgets('Opening settings', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final settingsButton = find.widgetWithIcon(
        MenuItemButton,
        Icons.settings,
      );

      expect(settingsButton, findsOneWidget);

      final settingsButtonWidget =
          settingsButton.evaluate().first.widget as MenuItemButton;

      settingsButtonWidget.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(find.byType(SettingsDialog), findsOneWidget);
    });

    testWidgets('Opening settings (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.comma);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.comma);

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await widgetTester.pumpAndSettle();

      expect(find.byType(SettingsDialog), findsOneWidget);
    });
  });

  group('[Notifications]:', () {
    testWidgets('Update Notification', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        updateChecker: createMockUpdateChecker(
          updateAvailable: true,
          latestVersion: '2025.0.1',
        ),
      );

      final notificationWidget = find.widgetWithText(
        ElegantNotification,
        'Version 2025.0.1 Available',
      );
      final notificationIcon = find.byIcon(Icons.update);

      expect(notificationWidget, findsOneWidget);
      expect(notificationIcon, findsOneWidget);
    });
  });
}
