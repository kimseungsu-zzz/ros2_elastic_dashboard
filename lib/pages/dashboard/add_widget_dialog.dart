import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/layout_drag_tile.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/layout_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget_style.dart';

class AddWidgetDialog extends StatefulWidget {
  final TabGridModel grid;
  final int gridIndex;
  final void Function(Offset, WidgetContainerModel) onWidgetDragUpdate;
  final void Function(WidgetContainerModel) onWidgetDragEnd;
  final void Function(Offset, LayoutContainerModel) onLayoutDragUpdate;
  final void Function(LayoutContainerModel) onLayoutDragEnd;
  final VoidCallback onClose;

  const AddWidgetDialog({
    super.key,
    required this.grid,
    required this.gridIndex,
    required this.onWidgetDragUpdate,
    required this.onWidgetDragEnd,
    required this.onLayoutDragUpdate,
    required this.onLayoutDragEnd,
    required this.onClose,
  });

  @override
  State<AddWidgetDialog> createState() => _AddWidgetDialogState();
}

class _AddWidgetDialogState extends State<AddWidgetDialog> {
  String _query = '';

  void onRemove(TabGridModel grid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      grid.removeDragInWidget();
    });
  }

  @override
  void didUpdateWidget(AddWidgetDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.grid != oldWidget.grid) onRemove(oldWidget.grid);
  }

  Widget _topicTile(RosTopicKey topic, {required bool camera, String? label}) =>
      LayoutDragTile<WidgetContainerModel>(
        key: ValueKey(topic),
        gridIndex: widget.gridIndex,
        title: label ?? topic.name,
        subtitle: topic.type,
        icon: camera ? Icons.videocam_outlined : Icons.sensors,
        layoutBuilder: () => widget.grid.createRosTopic(
          topic,
          style: camera ? TopicWidgetStyle.camera : null,
        ),
        onDragUpdate: widget.onWidgetDragUpdate,
        onDragEnd: widget.onWidgetDragEnd,
        onRemoveWidget: () => onRemove(widget.grid),
      );

  List<Widget> _topicRows(List<RosTopicKey> topics, [String prefix = '/']) {
    final folders = <String, List<RosTopicKey>>{};
    final leaves = <Widget>[];
    for (final topic in topics) {
      final label = topic.name.substring(prefix.length);
      final separator = label.indexOf('/');
      if (separator == -1) {
        leaves.add(_topicTile(topic, camera: false, label: label));
      } else {
        final folder = label.substring(0, separator);
        (folders[folder] ??= []).add(topic);
      }
    }
    return [
      for (final folder in folders.entries)
        ExpansionTile(
          key: PageStorageKey('$prefix${folder.key}'),
          title: Text(folder.key),
          initiallyExpanded: _query.isNotEmpty,
          controlAffinity: ListTileControlAffinity.leading,
          childrenPadding: const EdgeInsets.only(left: 12),
          children: _topicRows(folder.value, '$prefix${folder.key}/'),
        ),
      ...leaves,
    ];
  }

  Widget _topics({bool camera = false}) {
    final viewer = widget.grid.rosViewer;
    return ListenableBuilder(
      listenable: viewer,
      builder: (context, _) {
        if (!viewer.ready) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(viewer.status, textAlign: TextAlign.center),
                TextButton(onPressed: viewer.start, child: const Text('Retry')),
              ],
            ),
          );
        }
        final matches = [
          for (final topic in viewer.topics)
            for (final type in topic.types)
              if ((!camera || type == 'std_msgs/msg/String') &&
                  (topic.name.toLowerCase().contains(_query) ||
                      type.toLowerCase().contains(_query)))
                (name: topic.name, type: type),
        ];
        if (matches.isEmpty) {
          return Center(
            child: Text(
              _query.isEmpty
                  ? (camera
                        ? 'No camera URL topics discovered.'
                        : 'No ROS 2 topics discovered.')
                  : 'No matching topics.',
            ),
          );
        }
        return ListView(
          children: camera
              ? [for (final topic in matches) _topicTile(topic, camera: true)]
              : _topicRows(matches),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => DraggableDialog(
    dialog: Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            spreadRadius: -12.5,
            offset: Offset(5, 5),
            color: Colors.black87,
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.all(10),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const Icon(Icons.drag_handle, color: Colors.grey),
              const SizedBox(height: 10),
              Text(
                'Add Widget',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const TabBar(
                labelPadding: EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  Tab(text: 'ROS 2 Topics'),
                  Tab(text: 'Cameras'),
                  Tab(text: 'Layouts'),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _topics(),
                    _topics(camera: true),
                    ListView(
                      children: [
                        LayoutDragTile<LayoutContainerModel>(
                          gridIndex: widget.gridIndex,
                          title: 'List Layout',
                          icon: Icons.table_rows,
                          layoutBuilder: widget.grid.createListLayout,
                          onDragUpdate: widget.onLayoutDragUpdate,
                          onDragEnd: widget.onLayoutDragEnd,
                          onRemoveWidget: () => onRemove(widget.grid),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: DialogTextInput(
                        label: 'Search',
                        allowEmptySubmission: true,
                        updateOnChanged: true,
                        onSubmit: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
