import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class AccelerometerWidget extends TopicWidget {
  static const String widgetType = 'Accelerometer';

  const AccelerometerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, data, child) {
        final value = tryCast<num>(data)?.toDouble() ?? 0.0;

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(5.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${value.toStringAsFixed(2)} g',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
