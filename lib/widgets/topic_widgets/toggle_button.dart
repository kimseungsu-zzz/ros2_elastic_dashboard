import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class ToggleButton extends TopicWidget {
  static const String widgetType = 'Toggle Button';

  const ToggleButton({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();

    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, data, child) {
        bool value = tryCast(data) ?? false;

        String buttonText = model.topic.substring(
          model.topic.lastIndexOf('/') + 1,
        );

        Size buttonSize = MediaQuery.of(context).size;

        ThemeData theme = Theme.of(context);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: buttonSize.width * 0.01,
            vertical: buttonSize.height * 0.01,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 10),
            width: buttonSize.width,
            height: buttonSize.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(2, 2),
                  blurRadius: 10.0,
                  spreadRadius: -5,
                  color: Colors.black,
                ),
              ],
              color: (value)
                  ? theme.colorScheme.primaryContainer
                  : const Color.fromARGB(255, 50, 50, 50),
            ),
            child: Center(
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        );
      },
    );
  }
}
