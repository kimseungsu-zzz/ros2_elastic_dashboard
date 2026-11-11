import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class EncoderWidget extends TopicWidget {
  static const String widgetType = 'Encoder';

  const EncoderWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: [
            const Text('Distance'),
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
                  builder: (context, value, child) {
                    final distance = _measurement(
                      value,
                      'distance',
                      'position',
                    );
                    return SelectableText(
                      distance.toStringAsPrecision(10),
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
        ),
        Row(
          children: [
            const Text('Speed'),
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
                  builder: (context, value, child) {
                    final speed = _measurement(value, 'speed', 'velocity');
                    return SelectableText(
                      speed.toStringAsPrecision(10),
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
        ),
      ],
    );
  }

  double _measurement(Object? data, String field, String alternate) {
    if (data is! Map) return 0;
    final value = data[field] ?? data[alternate];
    if (value is num) return value.toDouble();
    if (value is List && value.length == 1 && value.single is num) {
      return (value.single as num).toDouble();
    }
    return 0;
  }
}
