import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

mixin DashboardPageSettings on DashboardPageViewModel {
  @override
  void displaySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        preferences: preferences,
        onGridToggle: toggleGrid,
        onGridSizeChanged: changeGridSize,
        onCornerRadiusChanged: changeCornerRadius,
        onResizeToDSChanged: changeResizeToDS,
        onRememberWindowPositionChanged: changeRememberWindowPosition,
        onLayoutLock: changeLayoutLock,
        onColorChanged: onColorChanged,
        onThemeVariantChanged: onThemeVariantChanged,
        onLogLevelChanged: changeLogLevel,
        onGridDPIChanged: changeGridDPI,
        onOpenAssetsFolderPressed: () async {
          Uri uri = Uri.file(
            '${path.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/',
          );
          if (await canLaunchUrl(uri)) {
            logger.info('Opening URL (assets folder): ${uri.toString()}');
            launchUrl(uri);
          }
        },
      ),
    );
  }

  Future<void> toggleGrid(bool value) async {
    await preferences.setBool(PrefKeys.showGrid, value);

    notifyListeners();
  }

  Future<void> changeGridSize(String? gridSize) async {
    if (state == null) {
      logger.warning('Attempting to change grid size while state is null');
      return;
    }
    if (gridSize == null) {
      return;
    }

    int? newGridSize = int.tryParse(gridSize);

    if (newGridSize == null ||
        newGridSize == 0 ||
        newGridSize == this.gridSize) {
      return;
    }

    bool? cancel =
        await showDialog<bool>(
          context: state!.context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.yellow),
                SizedBox(width: 5),
                Text('Grid Resizing Warning'),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resizing the grid may cause widgets to become misaligned due to sizing constraints. Manual work may be required after resizing.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Okay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ) ??
        true;

    if (cancel) {
      return;
    }

    int oldGridSize = this.gridSize;
    this.gridSize = newGridSize;

    await preferences.setInt(PrefKeys.gridSize, newGridSize);

    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.resizeGrid(oldGridSize, newGridSize);
    }

    notifyListeners();
  }

  Future<void> changeCornerRadius(String? radius) async {
    if (radius == null) {
      return;
    }

    double? newRadius = double.tryParse(radius);

    if (newRadius == null ||
        newRadius == preferences.getDouble(PrefKeys.cornerRadius)) {
      return;
    }

    await preferences.setDouble(PrefKeys.cornerRadius, newRadius);

    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.refreshAllContainers();
    }
    notifyListeners();
  }

  Future<void> changeResizeToDS(bool value) async {
    await preferences.setBool(PrefKeys.autoResizeToDS, value);
    updateDriverStationResize(value);
    notifyListeners();
  }

  Future<void> changeRememberWindowPosition(bool value) async {
    await preferences.setBool(PrefKeys.rememberWindowPosition, value);
  }

  Future<void> changeLayoutLock(bool value) async {
    if (value) {
      lockLayout();
    } else {
      unlockLayout();
    }
    notifyListeners();
  }

  Future<void> changeLogLevel(Level? level) async {
    if (level == null) {
      logger.info('Removing log level preference');
      await preferences.remove(PrefKeys.logLevel);
      Logger.level = Defaults.logLevel;
      return;
    }
    logger.info('Changing log level to ${level.levelName}');
    Logger.level = level;
    await preferences.setString(PrefKeys.logLevel, level.levelName);
  }

  Future<void> changeGridDPI(String? value) async {
    if (value == null) {
      return;
    }
    num? dpiOverride = double.tryParse(value) ?? int.tryParse(value);
    if (dpiOverride != null && dpiOverride <= 0) {
      return;
    }
    if (dpiOverride != null) {
      logger.info('Setting DPI override to ${dpiOverride.toDouble()}');
      await preferences.setDouble(
        PrefKeys.gridDpiOverride,
        dpiOverride.toDouble(),
      );
    } else {
      logger.info('Removing DPI override preference');
      await preferences.remove(PrefKeys.gridDpiOverride);
    }
    notifyListeners();
  }
}
