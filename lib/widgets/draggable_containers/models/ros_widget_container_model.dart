import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/ros/ros_graph.dart';

class RosWidgetContainerModel extends WidgetContainerModel {
  static const type = 'ROS 2 Viewer';

  final RosViewer viewer;

  RosWidgetContainerModel({
    required this.viewer,
    required super.preferences,
    required super.initialPosition,
  }) : super(title: type, enabled: true, minWidth: 256, minHeight: 256);

  RosWidgetContainerModel.fromJson({
    required this.viewer,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson(enabled: true, minWidth: 256, minHeight: 256);

  Widget get child => RosGraph(key: key, viewer: viewer);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'type': type};

  @override
  WidgetContainer getWidgetContainer(BuildContext context) => WidgetContainer(
    title: title,
    width: displayRect.width,
    height: displayRect.height,
    cornerRadius:
        preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
    child: child,
  );
}
