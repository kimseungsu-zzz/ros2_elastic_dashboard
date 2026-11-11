import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget_style.dart';

class RosTopicValue extends StatefulWidget {
  final RosViewer viewer;
  final RosTopicKey topic;
  final String fieldPath;
  final TopicWidgetModel model;
  final TopicWidgetStyle style;

  const RosTopicValue({
    super.key,
    required this.viewer,
    required this.topic,
    required this.fieldPath,
    required this.model,
    required this.style,
  });

  @override
  State<RosTopicValue> createState() => _RosTopicValueState();
}

class _RosTopicValueState extends State<RosTopicValue> {
  RosTopicKey? _binding;
  ValueNotifier<RosSample?>? _sample;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.viewer.addListener(_onGraph);
    _refreshBinding();
  }

  @override
  void didUpdateWidget(RosTopicValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewer != widget.viewer) {
      oldWidget.viewer.removeListener(_onGraph);
      _unwatch(oldWidget.viewer);
      widget.viewer.addListener(_onGraph);
    }
    final previousBinding = _binding;
    _refreshBinding();
    if (_binding == previousBinding &&
        (oldWidget.model != widget.model ||
            oldWidget.fieldPath != widget.fieldPath)) {
      _updateValue();
    }
  }

  @override
  void dispose() {
    widget.viewer.removeListener(_onGraph);
    _unwatch(widget.viewer);
    super.dispose();
  }

  void _unwatch(RosViewer viewer) {
    _sample?.removeListener(_onSample);
    if (_binding case final binding?) viewer.unwatchTopic(binding);
    _binding = null;
    _sample = null;
  }

  void _onGraph() {
    _refreshBinding();
    setState(() {});
  }

  void _refreshBinding() {
    var binding = widget.topic;
    if (binding.type.isEmpty) {
      final discovered = widget.viewer.topics
          .where((topic) => topic.name == binding.name)
          .firstOrNull;
      if (discovered == null || discovered.types.length != 1) {
        if (_binding != null) {
          _unwatch(widget.viewer);
          _updateValue();
        }
        return;
      }
      binding = (name: binding.name, type: discovered.types.single);
    }
    if (binding == _binding) return;
    _unwatch(widget.viewer);
    _binding = binding;
    _sample = widget.viewer.watchTopic(binding)..addListener(_onSample);
    _updateValue();
  }

  void _onSample() {
    final previousError = _error;
    _updateValue();
    if (previousError != _error) setState(() {});
  }

  void _updateValue() {
    final sample = _sample?.value;
    _error = null;
    Object? value = sample?.data;
    if (sample?.isError == true) {
      _error = sample!.text;
    } else if (sample != null) {
      if (widget.fieldPath.isEmpty) {
        if (value is Map && value.length == 1 && value.containsKey('data')) {
          value = value['data'];
        }
      } else {
        for (final segment in widget.fieldPath.split('.')) {
          final index = int.tryParse(segment);
          if (value is Map && value.containsKey(segment)) {
            value = value[segment];
          } else if (value is List &&
              index != null &&
              index >= 0 &&
              index < value.length) {
            value = value[index];
          } else {
            _error = 'Field not found: ${widget.fieldPath}';
            value = null;
            break;
          }
        }
      }
    }
    widget.model.subscription.receive(value);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(child: Text(error, overflow: TextOverflow.ellipsis));
    }
    if (_binding == null) {
      return Center(child: Text('Waiting for ${widget.topic.name}'));
    }

    return ChangeNotifierProvider<TopicWidgetModel>.value(
      value: widget.model,
      child: widget.style.build(),
    );
  }
}
