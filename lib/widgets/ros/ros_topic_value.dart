import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';

class RosTopicValue extends StatefulWidget {
  final RosViewer viewer;
  final RosTopicKey topic;
  final String fieldPath;

  const RosTopicValue({
    super.key,
    required this.viewer,
    required this.topic,
    required this.fieldPath,
  });

  @override
  State<RosTopicValue> createState() => _RosTopicValueState();
}

class _RosTopicValueState extends State<RosTopicValue> {
  late ValueNotifier<RosSample?> _sample;

  @override
  void initState() {
    super.initState();
    _sample = widget.viewer.watchTopic(widget.topic);
  }

  @override
  void didUpdateWidget(RosTopicValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewer != widget.viewer || oldWidget.topic != widget.topic) {
      oldWidget.viewer.unwatchTopic(oldWidget.topic);
      _sample = widget.viewer.watchTopic(widget.topic);
    }
  }

  @override
  void dispose() {
    widget.viewer.unwatchTopic(widget.topic);
    super.dispose();
  }

  String _format(RosSample sample) {
    if (sample.isError) return sample.text;

    Object? value = sample.data;
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
          return 'Field not found: ${widget.fieldPath}';
        }
      }
    }

    return value is String
        ? value
        : const JsonEncoder.withIndent('  ').convert(value);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewer,
    builder: (context, _) {
      final viewer = widget.viewer;
      final topic = widget.topic;
      final published = viewer.topics.any(
        (entry) =>
            entry.name == topic.name &&
            entry.types.contains(topic.type) &&
            entry.publishers.isNotEmpty,
      );

      return ValueListenableBuilder(
        valueListenable: _sample,
        builder: (context, sample, _) {
          final label = widget.fieldPath.isEmpty
              ? topic.type
              : '${topic.type} · ${widget.fieldPath}';
          final value = switch (sample) {
            final received? => _format(received),
            null when !viewer.ready => viewer.status,
            null when !published => 'Waiting for a publisher…',
            null => 'Waiting for a message…',
          };
          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Tooltip(
                  message: '${topic.name}\n$label',
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: sample?.isError == true
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
