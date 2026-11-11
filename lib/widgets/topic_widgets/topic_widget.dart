import 'package:flutter/foundation.dart';

import 'package:material_ui/material_ui.dart';

abstract class TopicWidget extends StatelessWidget {
  const TopicWidget({super.key});
}

class TopicWidgetModel extends ChangeNotifier {
  final String topic;
  final subscription = TopicWidgetValue();

  TopicWidgetModel(this.topic);

  Map<String, dynamic> toJson() => {};
  List<Widget> getEditProperties(BuildContext context) => const [];
  void refresh() => notifyListeners();

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }
}

class TopicWidgetValue extends ChangeNotifier
    implements ValueListenable<Object?> {
  Object? _value;

  @override
  Object? get value => _value;

  void receive(Object? value) {
    _value = value;
    notifyListeners();
  }
}
