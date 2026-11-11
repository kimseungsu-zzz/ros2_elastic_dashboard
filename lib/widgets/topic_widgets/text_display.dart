import 'dart:convert';

import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';

class TextDisplay extends TopicWidget {
  static const widgetType = 'Text Display';

  const TextDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TopicWidgetModel>();
    return ValueListenableBuilder(
      valueListenable: model.subscription,
      builder: (context, data, _) => _ReadOnlyText(data: data),
    );
  }
}

class _ReadOnlyText extends StatefulWidget {
  final Object? data;

  const _ReadOnlyText({required this.data});

  @override
  State<_ReadOnlyText> createState() => _ReadOnlyTextState();
}

class _ReadOnlyTextState extends State<_ReadOnlyText> {
  late final _controller = TextEditingController(text: _format(widget.data));

  String _format(Object? data) => switch (data) {
    null => '',
    final String text => text,
    List() || Map() => const JsonEncoder.withIndent('  ').convert(data),
    _ => data.toString(),
  };

  @override
  void didUpdateWidget(_ReadOnlyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _format(widget.data);
    if (_controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: TextField(
      controller: _controller,
      readOnly: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.bottom,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 10),
        isDense: true,
      ),
    ),
  );
}
