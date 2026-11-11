import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/widgets/ros/ros_graph.dart';

class DashboardPageFooter extends StatelessWidget {
  final DashboardPageViewModel model;
  final TextStyle? footerStyle;

  const DashboardPageFooter({
    super.key,
    required this.model,
    required this.footerStyle,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: const Color.fromARGB(255, 20, 20, 20),
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('ROS 2 Viewer'),
              content: SizedBox(
                width: 900,
                height: MediaQuery.of(context).size.height * 0.6,
                child: RosGraph(viewer: model.rosViewer),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: const Text('ROS 2 Graph'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ListenableBuilder(
            listenable: model.rosViewer,
            builder: (context, _) => Text(
              model.rosViewer.status,
              style: footerStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );
}
