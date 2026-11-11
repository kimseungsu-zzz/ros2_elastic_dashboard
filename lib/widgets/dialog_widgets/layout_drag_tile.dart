import 'package:flutter/gestures.dart';

import 'package:collection/collection.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/gesture/drag_container_listener.dart';

class LayoutDragTile<T extends WidgetContainerModel> extends StatelessWidget {
  final int gridIndex;
  final String title;
  final IconData icon;

  final T Function() layoutBuilder;

  final void Function(Offset globalPosition, T widget) onDragUpdate;

  final void Function(T widget) onDragEnd;

  final void Function() onRemoveWidget;

  const LayoutDragTile({
    super.key,
    required this.gridIndex,
    required this.title,
    required this.icon,
    required this.layoutBuilder,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRemoveWidget,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {},
    child: DragContainerListener<T>(
      gridIndex: gridIndex,
      supportedDevices: PointerDeviceKind.values
          .whereNot((element) => element == PointerDeviceKind.trackpad)
          .toSet(),
      onDragCreate: () => layoutBuilder.call(),
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      onRemoveWidget: onRemoveWidget,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16.0),
        child: ListTile(
          style: ListTileStyle.drawer,
          contentPadding: const EdgeInsets.only(right: 20.0),
          leading: Icon(icon),
          title: Text(title),
        ),
      ),
    ),
  );
}
