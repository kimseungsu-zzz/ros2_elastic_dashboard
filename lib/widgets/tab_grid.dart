import 'dart:math';

import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_ros_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/layout_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/list_layout_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/ros_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/gesture/context_menu_listener.dart';

// Used to refresh the tab grid when a widget is added or removed
// This doesn't use a stateful widget since everything has to be rendered at program startup or data will be lost
class TabGridModel extends ChangeNotifier {
  final RosViewer rosViewer;
  final SharedPreferences preferences;
  final List<WidgetContainerModel> _widgetModels = [];

  static Map<String, dynamic>? copyJsonData;

  MapEntry<WidgetContainerModel, Offset>? _containerDraggingIn;
  BuildContext? tabGridContext;

  final VoidCallback onAddWidgetPressed;

  bool _disposed = false;

  TabGridModel({
    required this.rosViewer,
    required this.preferences,
    required this.onAddWidgetPressed,
  });

  TabGridModel.fromJson({
    required this.rosViewer,
    required this.preferences,
    required Map<String, dynamic> jsonData,
    required this.onAddWidgetPressed,
    void Function(String message)? onJsonLoadingWarning,
  }) {
    loadFromJson(
      jsonData: jsonData,
      onJsonLoadingWarning: onJsonLoadingWarning,
    );
  }

  void loadFromJson({
    required Map<String, dynamic> jsonData,
    void Function(String message)? onJsonLoadingWarning,
  }) {
    if (jsonData['containers'] != null) {
      loadContainersFromJson(
        jsonData,
        onJsonLoadingWarning: onJsonLoadingWarning,
      );
    }

    if (jsonData['layouts'] != null) {
      loadLayoutsFromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);
    }
  }

  RosWidgetContainerModel? _readWidget(Map<String, dynamic> json) {
    if (json['type'] != RosWidgetContainerModel.type) return null;
    return RosWidgetContainerModel.fromJson(
      viewer: rosViewer,
      preferences: preferences,
      jsonData: json,
    );
  }

  void loadContainersFromJson(
    Map<String, dynamic> jsonData, {
    Function(String message)? onJsonLoadingWarning,
  }) {
    for (final item in jsonData['containers'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final widget = _readWidget(item);
      if (widget != null) addWidget(widget);
    }
  }

  ListLayoutModel _readListLayout(
    Map<String, dynamic> data, {
    Function(String message)? onJsonLoadingWarning,
  }) => ListLayoutModel.fromJson(
    preferences: preferences,
    jsonData: data,
    widgetBuilder: _readWidget,
    enabled: true,
    dragOutFunctions: (
      dragOutUpdate: layoutDragOutUpdate,
      dragOutEnd: layoutDragOutEnd,
    ),
    onDragCancel: _layoutContainerOnDragCancel,
    onJsonLoadingWarning: onJsonLoadingWarning,
  );

  void loadLayoutsFromJson(
    Map<String, dynamic> jsonData, {
    Function(String warningMessage)? onJsonLoadingWarning,
  }) {
    for (final item in jsonData['layouts'] as List) {
      if (item is! Map<String, dynamic> || item['type'] != 'List Layout') {
        continue;
      }
      addWidget(
        _readListLayout(item, onJsonLoadingWarning: onJsonLoadingWarning),
      );
    }
  }

  Map<String, dynamic> toJson() {
    var containers = [];
    var layouts = [];
    for (WidgetContainerModel model in _widgetModels) {
      if (model is RosWidgetContainerModel) {
        containers.add(model.toJson());
      } else {
        layouts.add(model.toJson());
      }
    }

    return {'layouts': layouts, 'containers': containers};
  }

  Offset getLocalPosition(Offset globalPosition) {
    if (tabGridContext == null) {
      return Offset.zero;
    }

    RenderBox? ancestor = tabGridContext!
        .findAncestorRenderObjectOfType<RenderBox>();

    Offset localPosition = ancestor!.globalToLocal(globalPosition);

    return localPosition;
  }

  Offset getDragInWidgetCenter(
    WidgetContainerModel widget,
    Offset globalPosition,
  ) {
    Offset localPosition =
        getLocalPosition(globalPosition) -
        Offset(widget.displayRect.width, widget.displayRect.height) / 2;

    if (localPosition.dy < 0 || localPosition.dx < 0) {
      localPosition = Offset(
        localPosition.dx.clamp(0, double.infinity),
        localPosition.dy.clamp(0, double.infinity),
      );
    }
    return localPosition;
  }

  bool isDraggingInContainer() => _containerDraggingIn != null;

  /// Returns weather `widget` is able to be moved to `location` without overlapping anything else.
  ///
  /// This only applies to widgets that already have a place on the grid
  bool isValidMoveLocation(WidgetContainerModel widget, Rect location) {
    Size? gridSize;
    if (tabGridContext != null) {
      gridSize = MediaQuery.of(tabGridContext!).size;
    }

    for (WidgetContainerModel container in _widgetModels) {
      if (container.displayRect.overlaps(location) && widget != container) {
        return false;
      } else if (gridSize != null &&
          (location.right > gridSize.width ||
              location.bottom > gridSize.height)) {
        return false;
      }
    }
    return true;
  }

  bool isValidLayoutLocation(Offset globalPosition) =>
      getLayoutAtLocation(globalPosition) != null;

  /// Returns weather `location` will overlap with widgets already on the dashboard
  bool isValidLocation(Rect location) {
    for (WidgetContainerModel container in _widgetModels) {
      if (container.displayRect.overlaps(location)) {
        return false;
      }
    }
    return true;
  }

  LayoutContainerModel? getLayoutAtLocation(Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    for (LayoutContainerModel container
        in _widgetModels.whereType<LayoutContainerModel>()) {
      if (container.displayRect.contains(localPosition)) {
        return container;
      }
    }

    return null;
  }

  void onWidgetResizeEnd(WidgetContainerModel model) {
    if (model.validLocation) {
      model.draggingRect = model.previewRect;
    } else {
      model.draggingRect = model.dragStartLocation;
    }

    model.displayRect = model.draggingRect;

    model.previewRect = model.draggingRect;
    model.previewVisible = false;
    model.validLocation = true;

    model.softDispose();
  }

  void onWidgetDragEnd(WidgetContainerModel model) {
    if (model.validLocation) {
      model.draggingRect = model.previewRect;
    } else {
      model.draggingRect = model.dragStartLocation;
    }

    model.displayRect = model.draggingRect;

    model.previewRect = model.draggingRect;
    model.previewVisible = false;
    model.validLocation = true;

    model.softDispose(deleting: false);
  }

  void onWidgetDragCancel(WidgetContainerModel model) {
    if (!model.dragging && !model.resizing) {
      return;
    }

    model.draggingRect = model.dragStartLocation;
    model.displayRect = model.draggingRect;
    model.previewRect = model.draggingRect;

    model.previewVisible = false;
    model.validLocation = true;

    model.dragging = false;
    model.resizing = false;
    model.draggingIntoLayout = false;

    model.softDispose();
  }

  void onWidgetUpdate(
    WidgetContainerModel model,
    Rect newRect,
    TransformResult result,
  ) {
    double newWidth = max(newRect.width, model.minWidth);
    double newHeight = max(newRect.height, model.minHeight);

    Rect constrainedRect = newRect;

    if (model.resizing) {
      if (result.handle.influencesLeft) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.right - newWidth,
          constrainedRect.top,
          constrainedRect.right,
          constrainedRect.bottom,
        );
      } else if (result.handle.influencesRight) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.left,
          constrainedRect.top,
          constrainedRect.left + newWidth,
          constrainedRect.bottom,
        );
      }

      if (result.handle.influencesTop) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.left,
          constrainedRect.bottom - newHeight,
          constrainedRect.right,
          constrainedRect.bottom,
        );
      } else if (result.handle.influencesBottom) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.left,
          constrainedRect.top,
          constrainedRect.right,
          constrainedRect.top + newHeight,
        );
      }
    } else {
      constrainedRect = Rect.fromLTWH(
        newRect.left,
        newRect.top,
        newWidth,
        newHeight,
      );
    }

    int gridSize = preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

    double previewX = DraggableWidgetContainer.snapToGrid(
      constrainedRect.left,
      gridSize,
    );
    double previewY = DraggableWidgetContainer.snapToGrid(
      constrainedRect.top,
      gridSize,
    );

    double previewWidth = DraggableWidgetContainer.snapToGrid(
      max(model.minWidth, constrainedRect.width),
      gridSize,
    );
    double previewHeight = DraggableWidgetContainer.snapToGrid(
      max(model.minHeight, constrainedRect.height),
      gridSize,
    );

    if (previewWidth < model.minWidth) {
      previewWidth = DraggableWidgetContainer.snapToGrid(
        max(model.minWidth, constrainedRect.width) + gridSize,
        gridSize,
      );
    }

    if (previewHeight < model.minHeight) {
      previewHeight = DraggableWidgetContainer.snapToGrid(
        max(model.minHeight, constrainedRect.height) + gridSize,
        gridSize,
      );
    }

    if (model.resizing) {
      if (result.handle.influencesLeft) {
        double snappedRight = DraggableWidgetContainer.snapToGrid(
          constrainedRect.right,
          gridSize,
        );
        previewX = snappedRight - previewWidth;
      }
      if (result.handle.influencesTop) {
        double snappedBottom = DraggableWidgetContainer.snapToGrid(
          constrainedRect.bottom,
          gridSize,
        );
        previewY = snappedBottom - previewHeight;
      }
    }

    Rect preview = Rect.fromLTWH(
      previewX,
      previewY,
      previewWidth,
      previewHeight,
    );

    model.draggingRect = constrainedRect;
    model.previewRect = preview;
    model.previewVisible = true;

    bool validLocation = isValidMoveLocation(model, preview);

    if (validLocation) {
      model.validLocation = true;
      model.draggingIntoLayout = false;
    } else {
      validLocation =
          isValidLayoutLocation(model.cursorGlobalLocation) &&
          model is! LayoutContainerModel &&
          !model.resizing;

      model.draggingIntoLayout = validLocation;
      model.validLocation = validLocation;
    }
  }

  void _widgetContainerOnUpdate(
    WidgetContainerModel widget,
    Rect newRect,
    TransformResult result,
  ) {
    onWidgetUpdate(widget, newRect, result);
  }

  void _widgetContainerOnDragBegin(WidgetContainerModel widget) {}

  void _widgetContainerOnDragEnd(
    WidgetContainerModel model,
    Rect releaseRect, {
    Offset? globalPosition,
  }) {
    onWidgetDragEnd(model);

    RosWidgetContainerModel widgetContainer = model as RosWidgetContainerModel;

    if (model.draggingIntoLayout && globalPosition != null) {
      LayoutContainerModel? layoutModel = getLayoutAtLocation(globalPosition);

      if (layoutModel != null) {
        layoutModel.addWidget(widgetContainer);
        _widgetModels.remove(widgetContainer);
        widgetContainer.removeListener(notifyListeners);
      }
    }
  }

  void _widgetContainerOnDragCancel(WidgetContainerModel widget) {
    onWidgetDragCancel(widget);
  }

  void _widgetContainerOnResizeBegin(WidgetContainerModel widget) {}

  void _widgetContainerOnResizeEnd(
    WidgetContainerModel widget,
    Rect releaseRect,
  ) {
    onWidgetResizeEnd(widget);
  }

  void _layoutContainerOnUpdate(
    WidgetContainerModel widget,
    Rect newRect,
    TransformResult result,
  ) {
    onWidgetUpdate(widget, newRect, result);
  }

  void _layoutContainerOnDragBegin(WidgetContainerModel widget) {}

  void _layoutContainerOnDragEnd(
    WidgetContainerModel widget,
    Rect releaseRect, {
    Offset? globalPosition,
  }) {
    onWidgetDragEnd(widget);
  }

  void _layoutContainerOnDragCancel(WidgetContainerModel widget) {
    onWidgetDragCancel(widget);
  }

  void _layoutContainerOnResizeBegin(WidgetContainerModel widget) {}

  void _layoutContainerOnResizeEnd(
    WidgetContainerModel widget,
    Rect releaseRect,
  ) {
    onWidgetResizeEnd(widget);
  }

  bool layoutDragOutEnd(WidgetContainerModel widget) {
    if (widget is RosWidgetContainerModel) {
      return placeDragInWidget(widget, true);
    }
    return false;
  }

  void layoutDragOutUpdate(WidgetContainerModel model, Offset globalPosition) =>
      addDragInWidget(model, globalPosition);

  void addDragInWidget(WidgetContainerModel widget, Offset globalPosition) {
    Offset center = getDragInWidgetCenter(widget, globalPosition);
    widget.draggingRect = Rect.fromLTWH(
      center.dx,
      center.dy,
      widget.draggingRect.width,
      widget.draggingRect.height,
    );

    _containerDraggingIn = MapEntry(widget, globalPosition);
    notifyListeners();
  }

  bool placeDragInWidget(
    WidgetContainerModel widget, [
    bool fromLayout = false,
  ]) {
    if (_containerDraggingIn == null) {
      return false;
    }

    Offset globalPosition = _containerDraggingIn!.value;

    Offset center = getDragInWidgetCenter(widget, globalPosition);

    int? gridSize = preferences.getInt(PrefKeys.gridSize);

    double previewX = DraggableWidgetContainer.snapToGrid(center.dx, gridSize);
    double previewY = DraggableWidgetContainer.snapToGrid(center.dy, gridSize);

    double width = widget.displayRect.width;
    double height = widget.displayRect.height;

    Rect previewLocation = Rect.fromLTWH(previewX, previewY, width, height);
    widget.previewRect = previewLocation;

    widget.enabled = true;

    // If dragging into layout
    if (widget is RosWidgetContainerModel &&
        isValidLayoutLocation(widget.cursorGlobalLocation)) {
      LayoutContainerModel layoutContainer = getLayoutAtLocation(
        widget.cursorGlobalLocation,
      )!;

      if (layoutContainer.willAcceptWidget(widget)) {
        layoutContainer.addWidget(widget);
      } else {
        widget.softDispose(deleting: !fromLayout);
        if (!fromLayout) {
          widget.unSubscribe();
          widget.dispose();
        }

        notifyListeners();
        return false;
      }
    } else if (!isValidMoveLocation(widget, previewLocation)) {
      _containerDraggingIn = null;

      widget.softDispose(deleting: !fromLayout);
      if (!fromLayout) {
        widget.unSubscribe();
        widget.dispose();
      }

      notifyListeners();
      return false;
    } else {
      widget.displayRect = previewLocation;
      widget.draggingRect = Rect.fromLTWH(previewX, previewY, width, height);

      addWidget(widget);
    }

    _containerDraggingIn = null;

    widget.softDispose();
    notifyListeners();

    return true;
  }

  void removeDragInWidget() {
    if (_disposed) {
      return;
    }
    if (_containerDraggingIn != null) {
      _containerDraggingIn = null;
      notifyListeners();
    }
  }

  RosWidgetContainerModel createRosViewer() {
    final size =
        (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) * 3.0;
    return RosWidgetContainerModel(
      viewer: rosViewer,
      preferences: preferences,
      initialPosition: Rect.fromLTWH(0, 0, max(size, 256), max(size, 256)),
    );
  }

  ListLayoutModel createListLayout({
    String title = 'List Layout',
    List<RosWidgetContainerModel>? children,
  }) => ListLayoutModel(
    preferences: preferences,
    title: title,
    initialPosition: Rect.fromLTWH(
      0.0,
      0.0,
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) * 2.0,
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) * 2.0,
    ),
    children: children,
    dragOutFunctions: (
      dragOutUpdate: layoutDragOutUpdate,
      dragOutEnd: layoutDragOutEnd,
    ),
    onDragCancel: _layoutContainerOnDragCancel,
  );

  void addWidget(WidgetContainerModel widget) {
    _widgetModels.add(widget);
    widget.addListener(notifyListeners);
    notifyListeners();
  }

  void removeWidget(WidgetContainerModel widget) {
    widget.removeListener(notifyListeners);
    widget.unSubscribe();
    widget.softDispose(deleting: true);
    widget.dispose();
    _widgetModels.remove(widget);
    notifyListeners();
  }

  @visibleForTesting
  void clearWidgets() {
    for (WidgetContainerModel container in _widgetModels) {
      container.removeListener(notifyListeners);
      container.unSubscribe();
      container.softDispose(deleting: true);
      container.dispose();
    }
    _widgetModels.clear();
    notifyListeners();
  }

  void confirmClearWidgets(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Clear'),
        content: const Text(
          'Are you sure you want to remove all widgets from this tab?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

              clearWidgets();
            },
            child: const Text('Confirm'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void copyWidget(WidgetContainerModel widget) {
    copyJsonData = widget.toJson();
  }

  void lockLayout() {
    for (WidgetContainerModel container in _widgetModels) {
      container.draggable = false;
    }
  }

  void unlockLayout() {
    for (WidgetContainerModel container in _widgetModels) {
      container.draggable = true;
    }
  }

  void onDestroy() {
    for (WidgetContainerModel container in _widgetModels) {
      container.removeListener(notifyListeners);
      container.softDispose(deleting: true);
      container.unSubscribe();
      container.dispose();
    }
    _widgetModels.clear();
  }

  void resizeGrid(int oldSize, int newSize) {
    for (WidgetContainerModel widget in _widgetModels) {
      widget.updateGridSize(oldSize, newSize);
    }
    notifyListeners();
  }

  void refreshAllContainers() {
    Future(() async {
      for (WidgetContainerModel widget in _widgetModels) {
        widget.notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    super.dispose();
  }
}

class TabGrid extends StatelessWidget {
  const TabGrid({super.key});

  @override
  Widget build(BuildContext context) {
    TabGridModel model = context.watch<TabGridModel>();

    model.tabGridContext = context;

    Widget getWidgetFromModel(WidgetContainerModel widgetModel) {
      if (widgetModel is RosWidgetContainerModel) {
        return ChangeNotifierProvider<RosWidgetContainerModel>.value(
          value: widgetModel,
          child: DraggableRosWidgetContainer(
            updateFunctions: (
              onUpdate: model._widgetContainerOnUpdate,
              onDragBegin: model._widgetContainerOnDragBegin,
              onDragEnd: model._widgetContainerOnDragEnd,
              onDragCancel: model._widgetContainerOnDragCancel,
              onResizeBegin: model._widgetContainerOnResizeBegin,
              onResizeEnd: model._widgetContainerOnResizeEnd,
              isValidMoveLocation: model.isValidMoveLocation,
            ),
          ),
        );
      } else if (widgetModel is ListLayoutModel) {
        return ChangeNotifierProvider<ListLayoutModel>.value(
          value: widgetModel,
          child: DraggableListLayout(
            updateFunctions: (
              onUpdate: model._layoutContainerOnUpdate,
              onDragBegin: model._layoutContainerOnDragBegin,
              onDragEnd: model._layoutContainerOnDragEnd,
              onDragCancel: model._layoutContainerOnDragCancel,
              onResizeBegin: model._layoutContainerOnResizeBegin,
              onResizeEnd: model._layoutContainerOnResizeEnd,
              isValidMoveLocation: model.isValidMoveLocation,
            ),
          ),
        );
      }
      return Container();
    }

    List<Widget> dashboardWidgets = [];
    List<Widget> draggingWidgets = [];
    List<Widget> draggingInWidgets = [];
    List<Widget> previewOutlines = [];

    for (WidgetContainerModel container in model._widgetModels) {
      if (container.dragging) {
        draggingWidgets.add(
          Positioned(
            left: container.draggingRect.left,
            top: container.draggingRect.top,
            child: IgnorePointer(
              child: container.getDraggingWidgetContainer(context),
            ),
          ),
        );

        if (!container.draggingIntoLayout) {
          previewOutlines.add(container.getDefaultPreview());
        } else {
          LayoutContainerModel? layoutContainer = model.getLayoutAtLocation(
            container.cursorGlobalLocation,
          );

          if (layoutContainer == null) {
            previewOutlines.add(container.getDefaultPreview());
          } else {
            previewOutlines.add(
              Positioned(
                left: layoutContainer.displayRect.left,
                top: layoutContainer.displayRect.top,
                width: layoutContainer.displayRect.width,
                height: layoutContainer.displayRect.height,
                child: Visibility(
                  visible: container.previewVisible,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(64),
                      borderRadius: BorderRadius.circular(
                        model.preferences.getDouble(PrefKeys.cornerRadius) ??
                            Defaults.cornerRadius,
                      ),
                      border: Border.all(color: Colors.yellow, width: 5.0),
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }

      dashboardWidgets.add(
        ContextMenuListener(
          key: container.key,
          onContextMenuGesture: (globalPosition, _) {
            if (model.preferences.getBool(PrefKeys.layoutLocked) ??
                Defaults.layoutLocked) {
              return;
            }
            List<ContextMenuEntry> menuEntries = [
              MenuHeader(text: container.title ?? '', disableUppercase: true),
              const MenuDivider(),
              MenuItem(
                label: const Text('Edit Properties'),
                icon: const Icon(Icons.edit_outlined),
                onSelected: (_) => container.showEditProperties(context),
              ),
              ...container.getContextMenuItems(),
              MenuItem(
                label: const Text('Copy'),
                icon: const Icon(Icons.copy_outlined),
                onSelected: (_) => model.copyWidget(container),
              ),
              MenuItem(
                label: const Text('Remove'),
                icon: const Icon(Icons.delete_outlined),
                onSelected: (_) => model.removeWidget(container),
              ),
            ];

            ContextMenu contextMenu = ContextMenu(
              position: globalPosition,
              borderRadius: BorderRadius.circular(5.0),
              padding: const EdgeInsets.all(4.0),
              entries: menuEntries,
            );

            showContextMenu(
              context,
              contextMenu: contextMenu,
              routeOptions: MenuRouteOptions(
                transitionDuration: const Duration(milliseconds: 100),
                reverseTransitionDuration: Duration.zero,
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) => FadeTransition(opacity: animation, child: child),
              ),
            );
          },
          child: getWidgetFromModel(container),
        ),
      );
    }

    // Also render any containers that are being dragged into the grid
    if (model._containerDraggingIn != null) {
      WidgetContainerModel container = model._containerDraggingIn!.key;

      draggingWidgets.add(
        Positioned(
          left: container.draggingRect.left,
          top: container.draggingRect.top,
          child: IgnorePointer(
            child: container.getDraggingWidgetContainer(context),
          ),
        ),
      );

      int? gridSize = model.preferences.getInt(PrefKeys.gridSize);

      double previewX = DraggableWidgetContainer.snapToGrid(
        container.draggingRect.left,
        gridSize,
      );
      double previewY = DraggableWidgetContainer.snapToGrid(
        container.draggingRect.top,
        gridSize,
      );

      Rect previewLocation = Rect.fromLTWH(
        previewX,
        previewY,
        container.displayRect.width,
        container.displayRect.height,
      );

      bool validLocation =
          model.isValidMoveLocation(container, previewLocation) ||
          model.isValidLayoutLocation(container.cursorGlobalLocation);

      Color borderColor = (validLocation)
          ? Colors.lightGreenAccent.shade400
          : Colors.red;

      if (model.isValidLayoutLocation(container.cursorGlobalLocation)) {
        LayoutContainerModel layoutContainer = model.getLayoutAtLocation(
          container.cursorGlobalLocation,
        )!;

        previewLocation = layoutContainer.displayRect;

        borderColor = Colors.yellow;
      }

      previewOutlines.add(
        Positioned(
          left: previewLocation.left,
          top: previewLocation.top,
          width: previewLocation.width,
          height: previewLocation.height,
          child: Container(
            decoration: BoxDecoration(
              color: (validLocation)
                  ? Colors.white.withAlpha(64)
                  : Colors.black.withAlpha(26),
              borderRadius: BorderRadius.circular(
                model.preferences.getDouble(PrefKeys.cornerRadius) ??
                    Defaults.cornerRadius,
              ),
              border: Border.all(color: borderColor, width: 5.0),
            ),
          ),
        ),
      );
    }

    return ContextMenuListener(
      behavior: HitTestBehavior.translucent,
      onContextMenuGesture: (globalPosition, localPosition) {
        if (model.preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }

        List<MenuItem> contextMenuEntries = [
          MenuItem(
            label: const Text('Add Widget'),
            icon: const Icon(Icons.add),
            onSelected: (_) => model.onAddWidgetPressed.call(),
          ),
          MenuItem(
            label: const Text('Clear Layout'),
            icon: const Icon(Icons.clear),
            onSelected: (_) => model.confirmClearWidgets(context),
          ),
        ];

        if (TabGridModel.copyJsonData != null) {
          contextMenuEntries.add(
            MenuItem(
              label: const Text('Paste'),
              icon: const Icon(Icons.paste_outlined),
              onSelected: (_) =>
                  pasteWidget(model, TabGridModel.copyJsonData, localPosition),
            ),
          );
        }

        ContextMenu contextMenu = ContextMenu(
          position: globalPosition,
          borderRadius: BorderRadius.circular(5.0),
          padding: const EdgeInsets.all(4.0),
          entries: contextMenuEntries,
        );

        showContextMenu(
          context,
          contextMenu: contextMenu,
          routeOptions: MenuRouteOptions(
            transitionDuration: const Duration(milliseconds: 100),
            reverseTransitionDuration: Duration.zero,
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) => FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {},
        child: Stack(
          children: [
            ...dashboardWidgets,
            ...previewOutlines,
            ...draggingWidgets,
            ...draggingInWidgets,
          ],
        ),
      ),
    );
  }

  void pasteWidget(
    TabGridModel grid,
    Map<String, dynamic>? widgetJson,
    Offset localPosition,
  ) {
    if (widgetJson == null) return;

    int gridSize =
        grid.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

    // Put the top left corner of the widget in the square the user pastes it in
    double snappedX = (localPosition.dx ~/ gridSize) * gridSize.toDouble();
    double snappedY = (localPosition.dy ~/ gridSize) * gridSize.toDouble();

    widgetJson['x'] = snappedX;
    widgetJson['y'] = snappedY;

    Rect pasteLocation = Rect.fromLTWH(
      snappedX,
      snappedY,
      widgetJson['width'],
      widgetJson['height'],
    );

    if (grid.isValidLocation(pasteLocation)) {
      WidgetContainerModel? copiedWidget = createWidgetFromJson(
        grid,
        widgetJson,
      );

      if (copiedWidget != null) grid.addWidget(copiedWidget);
    }
  }

  WidgetContainerModel? createWidgetFromJson(
    TabGridModel grid,
    Map<String, dynamic> json,
  ) => json['type'] == 'List Layout'
      ? grid._readListLayout(json)
      : grid._readWidget(json);
}
