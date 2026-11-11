import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class NumberSliderModel extends TopicWidgetModel {
  double _minValue = -1.0;
  double _maxValue = 1.0;
  int _divisions = 5;

  double get minValue => _minValue;

  set minValue(double value) {
    _minValue = value;
    refresh();
  }

  double get maxValue => _maxValue;

  set maxValue(double value) {
    _maxValue = value;
    refresh();
  }

  int get divisions => _divisions;

  set divisions(int value) {
    _divisions = value;
    refresh();
  }

  NumberSliderModel.fromJson(super.topic, Map<String, dynamic> jsonData)
    : super() {
    _minValue =
        tryCast(jsonData['min_value']) ?? tryCast(jsonData['min']) ?? -1.0;
    _maxValue =
        tryCast(jsonData['max_value']) ?? tryCast(jsonData['max']) ?? 1.0;
    _divisions =
        tryCast(jsonData['divisions']) ??
        tryCast(jsonData['numOfTickMarks']) ??
        5;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'min_value': _minValue,
    'max_value': _maxValue,
    'divisions': _divisions,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    // Min and max values
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMin = double.tryParse(value);
              if (newMin == null) {
                return;
              }
              minValue = newMin;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Min Value',
            initialText: _minValue.toString(),
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMax = double.tryParse(value);
              if (newMax == null) {
                return;
              }
              maxValue = newMax;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Max Value',
            initialText: _maxValue.toString(),
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    // Number of divisions
    Row(
      children: [
        Flexible(
          flex: 2,
          child: DialogTextInput(
            onSubmit: (value) {
              int? newDivisions = int.tryParse(value);
              if (newDivisions == null || newDivisions < 2) {
                return;
              }
              divisions = newDivisions;
            },
            formatter: FilteringTextInputFormatter.digitsOnly,
            label: 'Divisions',
            initialText: _divisions.toString(),
          ),
        ),
      ],
    ),
  ];
}

class NumberSlider extends TopicWidget {
  static const String widgetType = 'Number Slider';

  const NumberSlider({super.key});

  @override
  Widget build(BuildContext context) {
    NumberSliderModel model = cast(context.watch<TopicWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, data, child) {
        final value = tryCast<num>(data)?.toDouble() ?? 0.0;
        final clampedValue = value.clamp(model.minValue, model.maxValue);
        double divisionSeparation =
            (model.maxValue - model.minValue) / (model.divisions - 1);

        int fractionDigits = (data is int) ? 0 : 2;

        return Column(
          children: [
            Text(
              value.toStringAsFixed(fractionDigits),
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
            Expanded(
              child: LinearGauge(
                rulers: RulerStyle(
                  rulerPosition: RulerPosition.bottom,
                  showLabel: true,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                  primaryRulerColor: Colors.grey,
                  secondaryRulerColor: Colors.grey,
                ),
                extendLinearGauge: 1,
                linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
                  backgroundColor: Color.fromRGBO(87, 87, 87, 1),
                  thickness: 5,
                ),
                pointers: [
                  Pointer(
                    color: Theme.of(context).colorScheme.primary,
                    value: clampedValue,
                    shape: PointerShape.circle,
                    enableAnimation: false,
                    height: 15,
                    isInteractive: false,
                  ),
                ],
                customLabels: [
                  for (int i = 0; i < model.divisions; i++)
                    CustomRulerLabel(
                      text: (model.minValue + divisionSeparation * i)
                          .toStringAsFixed(2),
                      value: model.minValue + divisionSeparation * i,
                    ),
                ],
                enableGaugeAnimation: false,
                start: model.minValue,
                end: model.maxValue,
                steps: divisionSeparation,
              ),
            ),
          ],
        );
      },
    );
  }
}
