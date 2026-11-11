import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/layout_drag_tile.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/layout_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

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

  Widget _topicTile(RosTopicKey topic) => LayoutDragTile<WidgetContainerModel>(
    key: ValueKey(topic),
    gridIndex: widget.gridIndex,
    title: topic.name,
    subtitle: topic.type,
    icon: Icons.sensors,
    layoutBuilder: () => widget.grid.createRosTopic(topic),
    onDragUpdate: widget.onWidgetDragUpdate,
    onDragEnd: widget.onWidgetDragEnd,
    onRemoveWidget: () => onRemove(widget.grid),
  );

  Widget _topics() {
    final viewer = widget.grid.rosViewer;
    return Column(
      children: [
        DialogTextInput(
          label: 'Search topics or types',
          allowEmptySubmission: true,
          updateOnChanged: true,
          onSubmit: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: viewer,
            builder: (context, _) {
              if (!viewer.ready) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(viewer.status, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: viewer.start,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final matches = [
                for (final topic in viewer.topics)
                  for (final type in topic.types)
                    if (topic.name.toLowerCase().contains(_query) ||
                        type.toLowerCase().contains(_query))
                      (name: topic.name, type: type),
              ];
              if (matches.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No ROS 2 topics discovered.'
                        : 'No matching topics.',
                  ),
                );
              }
              return ListView(children: matches.map(_topicTile).toList());
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DraggableDialog(
    dialog: Card(
      margin: const EdgeInsets.all(10),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            Text('Add Widget', style: Theme.of(context).textTheme.titleMedium),
            const TabBar(
              tabs: [
                Tab(text: 'ROS 2 Topics'),
                Tab(text: 'Layouts'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _topics(),
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
                      LayoutDragTile<WidgetContainerModel>(
                        gridIndex: widget.gridIndex,
                        title: 'ROS 2 Viewer',
                        icon: Icons.account_tree,
                        layoutBuilder: widget.grid.createRosViewer,
                        onDragUpdate: widget.onWidgetDragUpdate,
                        onDragEnd: widget.onWidgetDragEnd,
                        onRemoveWidget: () => onRemove(widget.grid),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(onPressed: widget.onClose, child: const Text('Close')),
          ],
        ),
      ),
    ),
  );
}
