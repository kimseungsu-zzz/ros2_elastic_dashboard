import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';

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
    alignment: Alignment.centerLeft,
    child: ListenableBuilder(
      listenable: model.rosViewer,
      builder: (context, _) => Text(
        model.rosViewer.status,
        style: footerStyle?.copyWith(
          color: model.rosViewer.ready ? Colors.green : Colors.red,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
