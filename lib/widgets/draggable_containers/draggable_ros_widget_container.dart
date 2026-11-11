import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/ros_widget_container_model.dart';

class DraggableRosWidgetContainer extends DraggableWidgetContainer {
  const DraggableRosWidgetContainer({super.key, super.updateFunctions})
    : super();

  @override
  Widget build(BuildContext context) {
    RosWidgetContainerModel model = context.watch<RosWidgetContainerModel>();

    return Stack(
      children: [
        Positioned(
          left: model.displayRect.left,
          top: model.displayRect.top,
          child: model.getWidgetContainer(context),
        ),
        ...super.getStackChildren(model),
      ],
    );
  }
}
