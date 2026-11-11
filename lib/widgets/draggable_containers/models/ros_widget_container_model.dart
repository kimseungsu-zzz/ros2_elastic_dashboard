import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/ros/ros_graph.dart';
import 'package:elastic_dashboard/widgets/ros/ros_topic_value.dart';

class RosWidgetContainerModel extends WidgetContainerModel {
  static const graphType = 'ROS 2 Viewer';
  static const topicType = 'ROS 2 Topic';

  final RosViewer viewer;
  final RosTopicKey? topic;
  String _fieldPath = '';

  String get type => topic == null ? graphType : topicType;

  RosWidgetContainerModel({
    required this.viewer,
    required super.preferences,
    required super.initialPosition,
    this.topic,
  }) : super(
         title: topic?.name ?? graphType,
         enabled: true,
         minWidth: topic == null ? 256 : 128,
         minHeight: topic == null ? 256 : 128,
       );

  RosWidgetContainerModel.fromJson({
    required this.viewer,
    required super.preferences,
    required super.jsonData,
    required this.topic,
  }) : _fieldPath = switch (jsonData['field_path']) {
         final String value => value,
         _ => '',
       },
       super.fromJson(
         enabled: true,
         minWidth: topic == null ? 256 : 128,
         minHeight: topic == null ? 256 : 128,
       );

  Widget get child => switch (topic) {
    final binding? => RosTopicValue(
      key: key,
      viewer: viewer,
      topic: binding,
      fieldPath: _fieldPath,
    ),
    null => RosGraph(key: key, viewer: viewer),
  };

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': type,
    if (topic case final binding?) ...{
      'topic': binding.name,
      'message_type': binding.type,
      if (_fieldPath.isNotEmpty) 'field_path': _fieldPath,
    },
  };

  List<Widget> getTopicEditProperties({VoidCallback? onChanged}) => [
    if (topic case final binding?) ...[
      const SizedBox(height: 8),
      Text('${binding.name} · ${binding.type}'),
      DialogTextInput(
        label: 'Field path (e.g. orientation.x)',
        initialText: _fieldPath,
        allowEmptySubmission: true,
        updateOnChanged: true,
        onSubmit: (value) {
          final fieldPath = value.trim();
          if (_fieldPath == fieldPath) return;
          _fieldPath = fieldPath;
          notifyListeners();
          onChanged?.call();
        },
      ),
    ],
  ];

  @override
  List<Widget> getContainerEditProperties() => [
    ...super.getContainerEditProperties(),
    ...getTopicEditProperties(),
  ];

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
