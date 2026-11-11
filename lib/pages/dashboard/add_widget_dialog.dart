import 'package:material_ui/material_ui.dart';

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

  @override
  Widget build(BuildContext context) => DraggableDialog(
    dialog: Card(
      margin: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Icon(Icons.drag_handle, color: Colors.grey),
          Text('Add Widget', style: Theme.of(context).textTheme.titleMedium),
          Expanded(
            child: ListView(
              children: [
                LayoutDragTile<WidgetContainerModel>(
                  gridIndex: widget.gridIndex,
                  title: 'ROS 2 Viewer',
                  icon: Icons.account_tree,
                  layoutBuilder: widget.grid.createRosViewer,
                  onDragUpdate: widget.onWidgetDragUpdate,
                  onDragEnd: widget.onWidgetDragEnd,
                  onRemoveWidget: () => onRemove(widget.grid),
                ),
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
          ),
          TextButton(onPressed: widget.onClose, child: const Text('Close')),
        ],
      ),
    ),
  );
}
