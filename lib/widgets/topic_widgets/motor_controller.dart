import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class MotorController extends TopicWidget {
  static const String widgetType = 'Motor Controller';

  const MotorController({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, data, child) {
        final value = tryCast<num>(data)?.toDouble() ?? 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Flexible(child: SizedBox(height: 5)),
            LinearGauge(
              rulers: RulerStyle(
                rulerPosition: RulerPosition.bottom,
                primaryRulerColor: Colors.grey,
                secondaryRulerColor: Colors.grey,
                textStyle: Theme.of(context).textTheme.bodySmall,
              ),
              extendLinearGauge: 1,
              linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
                backgroundColor: Color.fromRGBO(87, 87, 87, 1),
                thickness: 5,
              ),
              pointers: [
                Pointer(
                  enableAnimation: false,
                  value: value.clamp(-1.0, 1.0),
                  shape: PointerShape.diamond,
                  color: Theme.of(context).colorScheme.primary,
                  width: 10.0,
                  height: 14.0,
                ),
              ],
              enableGaugeAnimation: false,
              start: -1.0,
              end: 1.0,
              steps: 0.5,
            ),
          ],
        );
      },
    );
  }
}
