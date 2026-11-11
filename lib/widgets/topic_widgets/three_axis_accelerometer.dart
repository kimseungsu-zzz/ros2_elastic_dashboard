import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class ThreeAxisAccelerometer extends TopicWidget {
  static const String widgetType = '3-Axis Accelerometer';

  const ThreeAxisAccelerometer({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        // X Acceleration
        Flexible(
          flex: 16,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('X'),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder(
                    valueListenable: model.subscription,
                    builder: (context, value, child) {
                      final xAccel = _acceleration(value, 'x');
                      return Text(
                        '${xAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Flexible(child: SizedBox(height: 4.0)),
        // Y Acceleration
        Flexible(
          flex: 16,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Y'),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder(
                    valueListenable: model.subscription,
                    builder: (context, value, child) {
                      final yAccel = _acceleration(value, 'y');
                      return Text(
                        '${yAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Flexible(child: SizedBox(height: 4.0)),
        // Z Acceleration
        Flexible(
          flex: 16,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Z'),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder(
                    valueListenable: model.subscription,
                    builder: (context, value, child) {
                      final zAccel = _acceleration(value, 'z');
                      return Text(
                        '${zAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _acceleration(Object? data, String axis) {
    if (data is! Map) return 0;
    final acceleration = data['linear_acceleration'];
    if (acceleration is Map && acceleration[axis] is num) {
      return (acceleration[axis] as num).toDouble() / 9.80665;
    }
    final value = data[axis];
    return value is num ? value.toDouble() : 0;
  }
}
