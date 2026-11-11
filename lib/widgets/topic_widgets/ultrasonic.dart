import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class Ultrasonic extends TopicWidget {
  static const String widgetType = 'Ultrasonic';

  const Ultrasonic({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return Row(
      children: [
        const Text('Range'),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade700, width: 1.5),
              ),
            ),
            child: ValueListenableBuilder(
              valueListenable: model.subscription,
              builder: (context, data, child) {
                final range = data is Map ? tryCast<num>(data['range']) : null;
                final value = range != null
                    ? range / 0.0254
                    : tryCast<num>(data)?.toDouble() ?? 0.0;
                return SelectableText(
                  '${value.toStringAsPrecision(5)} in',
                  maxLines: 1,
                  showCursor: true,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
