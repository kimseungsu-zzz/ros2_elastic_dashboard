import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class LargeTextDisplay extends TopicWidget {
  static const String widgetType = 'Large Text Display';

  const LargeTextDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, value, _) {
        String data = value?.toString() ?? '';

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(data, textAlign: TextAlign.center),
              ),
            ),
          ],
        );
      },
    );
  }
}
