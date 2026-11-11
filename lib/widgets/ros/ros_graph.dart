import 'package:flutter/material.dart' as material;

import 'package:elastic_dashboard/services/ros_viewer.dart';

class RosGraph extends material.StatefulWidget {
  final RosViewer viewer;

  const RosGraph({super.key, required this.viewer});

  @override
  material.State<RosGraph> createState() => _RosGraphState();
}

class _RosGraphState extends material.State<RosGraph> {
  RosTopicKey? _selection;
  material.ValueNotifier<RosSample?>? _sample;
  String _query = '';

  @override
  void dispose() {
    if (_selection case final key?) widget.viewer.unwatchTopic(key);
    super.dispose();
  }

  void _select(RosTopicKey key) {
    if (_selection == key) return;
    if (_selection case final previous?) widget.viewer.unwatchTopic(previous);
    setState(() {
      _selection = key;
      _sample = widget.viewer.watchTopic(key);
    });
  }

  @override
  material.Widget build(
    material.BuildContext context,
  ) => material.ListenableBuilder(
    listenable: widget.viewer,
    builder: (context, _) {
      final viewer = widget.viewer;
      if (!viewer.ready) {
        return material.Center(
          child: material.Padding(
            padding: const material.EdgeInsets.all(16),
            child: material.Column(
              mainAxisSize: material.MainAxisSize.min,
              children: [
                material.Text(
                  viewer.status,
                  textAlign: material.TextAlign.center,
                ),
                material.TextButton(
                  onPressed: viewer.start,
                  child: const material.Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      final nodes = viewer.nodes.where(
        (node) => node.toLowerCase().contains(_query),
      );
      final topics = viewer.topics
          .where(
            (topic) => [
              topic.name,
              ...topic.types,
              ...topic.publishers,
              ...topic.subscribers,
            ].any((value) => value.toLowerCase().contains(_query)),
          )
          .toList();
      final selection = _selection;
      final selectedTopic = selection == null
          ? null
          : viewer.topics
                .where(
                  (topic) =>
                      topic.name == selection.name &&
                      topic.types.contains(selection.type),
                )
                .firstOrNull;

      return material.Padding(
        padding: const material.EdgeInsets.all(8),
        child: material.Column(
          crossAxisAlignment: material.CrossAxisAlignment.stretch,
          children: [
            material.TextField(
              decoration: const material.InputDecoration(
                prefixIcon: material.Icon(material.Icons.search),
                hintText: 'Filter nodes, topics, or types',
                isDense: true,
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            material.Expanded(
              flex: 3,
              child: material.ListView(
                children: [
                  material.ExpansionTile(
                    title: material.Text('Nodes (${viewer.nodes.length})'),
                    children: [
                      for (final node in nodes)
                        material.ListTile(
                          dense: true,
                          title: material.SelectableText(node),
                        ),
                    ],
                  ),
                  if (topics.isEmpty)
                    const material.ListTile(
                      title: material.Text('No matching ROS 2 topics'),
                    ),
                  if (topics.isNotEmpty)
                    const material.Row(
                      children: [
                        material.Expanded(
                          child: material.Center(
                            child: material.Text('Publishers'),
                          ),
                        ),
                        material.Expanded(
                          flex: 2,
                          child: material.Center(
                            child: material.Text('Topics'),
                          ),
                        ),
                        material.Expanded(
                          child: material.Center(
                            child: material.Text('Subscribers'),
                          ),
                        ),
                      ],
                    ),
                  for (final topic in topics) _topicRow(topic),
                ],
              ),
            ),
            const material.Divider(),
            material.Expanded(
              flex: 2,
              child: selection == null
                  ? const material.Text(
                      'Select a topic to view live messages.',
                    )
                  : material.Column(
                      crossAxisAlignment: material.CrossAxisAlignment.stretch,
                      children: [
                        material.Text(
                          '${selection.name} · ${selection.type}',
                          maxLines: 2,
                          overflow: material.TextOverflow.ellipsis,
                        ),
                        material.Expanded(
                          child: selectedTopic == null
                              ? const material.Text(
                                  'Topic is no longer available.',
                                )
                              : material.ValueListenableBuilder<RosSample?>(
                                  valueListenable: _sample!,
                                  builder: (context, sample, _) =>
                                      material.SingleChildScrollView(
                                        child: material.SelectableText(
                                          sample?.text ??
                                              (selectedTopic.publishers.isEmpty
                                                  ? 'No active publishers.'
                                                  : 'Waiting for a message…'),
                                          style: material.TextStyle(
                                            fontFamily: 'monospace',
                                            color: sample?.isError == true
                                                ? material.Theme.of(context)
                                                      .colorScheme
                                                      .error
                                                : null,
                                          ),
                                        ),
                                      ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );

  material.Widget _topicRow(RosTopic topic) => material.Padding(
    padding: const material.EdgeInsets.symmetric(vertical: 4),
    child: material.Row(
      crossAxisAlignment: material.CrossAxisAlignment.center,
      children: [
        material.Expanded(child: _endpoints(topic.publishers, 'Publishers')),
        const material.Icon(material.Icons.arrow_forward, size: 16),
        material.Expanded(
          flex: 2,
          child: material.Column(
            children: [
              if (topic.types.length == 1)
                material.TextButton(
                  onPressed: () =>
                      _select((name: topic.name, type: topic.types.single)),
                  child: material.Column(
                    children: [
                      material.Text(
                        topic.name,
                        textAlign: material.TextAlign.center,
                      ),
                      material.Text(
                        topic.types.single,
                        textAlign: material.TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                material.Text(topic.name, textAlign: material.TextAlign.center),
              if (topic.types.length > 1)
                for (final type in topic.types)
                  material.TextButton(
                    onPressed: () => _select((name: topic.name, type: type)),
                    child: material.Text(
                      type,
                      textAlign: material.TextAlign.center,
                    ),
                  ),
            ],
          ),
        ),
        const material.Icon(material.Icons.arrow_forward, size: 16),
        material.Expanded(child: _endpoints(topic.subscribers, 'Subscribers')),
      ],
    ),
  );

  material.Widget _endpoints(List<String> names, String label) =>
      material.Tooltip(
        message: label,
        child: material.Text(
          names.isEmpty ? '—' : names.join('\n'),
          textAlign: material.TextAlign.center,
        ),
      );
}
