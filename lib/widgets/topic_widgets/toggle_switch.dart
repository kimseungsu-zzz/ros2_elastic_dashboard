import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class ToggleSwitch extends TopicWidget {
  static const String widgetType = 'Toggle Switch';

  const ToggleSwitch({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, data, child) {
        bool value = tryCast(data) ?? false;

        return IgnorePointer(
          child: Switch(value: value, onChanged: (_) {}),
        );
      },
    );
  }
}
