import 'package:flutter_context_menu/flutter_context_menu.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/ros/ros_graph.dart';
import 'package:elastic_dashboard/widgets/ros/ros_topic_value.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget_style.dart';

class RosWidgetContainerModel extends WidgetContainerModel {
  static const graphType = 'ROS 2 Viewer';
  static const topicType = 'ROS 2 Topic';

  final RosViewer viewer;
  RosTopicKey? _topic;
  String _fieldPath = '';
  TopicWidgetStyle? _style;
  TopicWidgetModel? _widgetModel;

  String get type => _style?.label ?? graphType;

  RosWidgetContainerModel({
    required this.viewer,
    required super.preferences,
    required super.initialPosition,
    RosTopicKey? topic,
    TopicWidgetStyle? style,
  }) : _topic = topic,
       super(title: topic?.name ?? graphType, enabled: true) {
    if (topic != null) {
      _setStyle(style ?? TopicWidgetStyle.defaultFor(topic.type));
    } else {
      minWidth = minHeight = 256;
    }
  }

  RosWidgetContainerModel.fromJson({
    required this.viewer,
    required super.preferences,
    required Map<String, dynamic> jsonData,
    required RosTopicKey? topic,
    required TopicWidgetStyle? style,
  }) : _topic = topic,
       super.fromJson(jsonData: jsonData, enabled: true) {
    if (topic != null && style != null) {
      final props = jsonData['properties'];
      _fieldPath = switch (jsonData['field_path']) {
        final String value => value,
        _ => '',
      };
      _setStyle(style, props is Map<String, dynamic> ? props : const {});
    } else {
      minWidth = minHeight = 256;
    }
  }

  void _setStyle(
    TopicWidgetStyle style, [
    Map<String, dynamic> properties = const {},
  ]) {
    _widgetModel?.dispose();
    _style = style;
    _widgetModel = style.createModel(_topic!.name, properties);
    _updateMinimumSize();
  }

  void _updateMinimumSize() {
    final cellSize = preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;
    minWidth = minHeight = _style == null ? 256 : cellSize * _style!.minCells;
  }

  @override
  void updateGridSize(int oldGridSize, int newGridSize) {
    _updateMinimumSize();
    super.updateGridSize(oldGridSize, newGridSize);
  }

  void _changeStyle(TopicWidgetStyle style) {
    if (_style == style) return;
    _setStyle(style);
    notifyListeners();
  }

  void _changeTopic(String name) {
    final trimmed = name.trim();
    if (!trimmed.startsWith('/') || trimmed == _topic?.name) return;
    final discovered = viewer.topics
        .where((topic) => topic.name == trimmed)
        .firstOrNull;
    final matching = discovered?.types ?? const <String>[];
    final previous = _topic!.type;
    final type = matching.contains(previous)
        ? previous
        : matching.length == 1
        ? matching.single
        : '';
    _topic = (name: trimmed, type: type);
    _setStyle(_style!, _widgetModel!.toJson());
    notifyListeners();
  }

  Widget get child => switch (_topic) {
    final binding? => RosTopicValue(
      key: key,
      viewer: viewer,
      topic: binding,
      fieldPath: _fieldPath,
      model: _widgetModel!,
      style: _style!,
    ),
    null => RosGraph(key: key, viewer: viewer),
  };

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': type,
    if (_topic case final binding?) ...{
      'topic': binding.name,
      'message_type': binding.type,
      if (_fieldPath.isNotEmpty) 'field_path': _fieldPath,
      'properties': _widgetModel!.toJson(),
    },
  };

  @override
  List<ContextMenuEntry> getContextMenuItems() => [
    if (_topic != null)
      MenuItem.submenu(
        label: const Text('Show As'),
        items: [
          for (final style in TopicWidgetStyle.values)
            MenuItem(
              label: Text(style.label),
              icon: Icon(_style == style ? Icons.check : null),
              onSelected: (_) => _changeStyle(style),
            ),
        ],
      ),
  ];

  List<Widget> getTopicEditProperties({VoidCallback? onChanged}) => [
    if (_topic != null)
      StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 5),
            const Center(child: Text('Widget Type')),
            DialogDropdownChooser<TopicWidgetStyle>(
              choices: TopicWidgetStyle.values,
              initialValue: _style,
              nameMap: (style) => style.label,
              onSelectionChanged: (style) {
                if (style == null) return;
                setState(() => _changeStyle(style));
                onChanged?.call();
              },
            ),
            const Divider(),
            ..._widgetModel!.getEditProperties(context),
            DialogTextInput(
              label: 'Topic',
              initialText: _topic!.name,
              onSubmit: (name) {
                _changeTopic(name);
                onChanged?.call();
              },
            ),
            DialogTextInput(
              label: 'Field path',
              initialText: _fieldPath,
              allowEmptySubmission: true,
              onSubmit: (value) {
                final fieldPath = value.trim();
                if (_fieldPath == fieldPath) return;
                _fieldPath = fieldPath;
                notifyListeners();
                onChanged?.call();
              },
            ),
          ],
        ),
      ),
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

  @override
  void dispose() {
    _widgetModel?.dispose();
    super.dispose();
  }
}
