import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as ui;

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/widgets/ros/ros_graph.dart';
import 'package:elastic_dashboard/widgets/ros/ros_topic_value.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget_style.dart';

class TestRosViewer extends RosViewer {
  final sample = ValueNotifier<RosSample?>(null);
  RosTopicKey? watched;

  void updateGraph(
    List<String> discoveredNodes,
    List<RosTopic> discoveredTopics,
  ) {
    ready = true;
    nodes = discoveredNodes;
    topics = discoveredTopics;
    notifyListeners();
  }

  @override
  ValueNotifier<RosSample?> watchTopic(RosTopicKey key) {
    watched = key;
    return sample;
  }

  @override
  void unwatchTopic(RosTopicKey key) {
    watched = null;
  }

  @override
  void dispose() {
    sample.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets('a topic widget keeps its binding and projects a nested field', (
    tester,
  ) async {
    final viewer = TestRosViewer();
    addTearDown(viewer.dispose);
    const key = (name: '/imu', type: 'sensor_msgs/msg/Imu');
    final model = TopicWidgetModel(key.name);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ui.MaterialApp(
        home: ui.Scaffold(
          body: RosTopicValue(
            viewer: viewer,
            topic: key,
            fieldPath: 'orientation.x',
            model: model,
            style: TopicWidgetStyle.text,
          ),
        ),
      ),
    );
    expect(viewer.watched, key);

    viewer.sample.value = const RosSample(
      'IMU sample',
      data: {
        'orientation': {'x': 0.012, 'y': 0.001},
      },
    );
    await tester.pump();
    expect(find.text('0.012'), findsOneWidget);
    expect(find.textContaining('0.001'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    expect(viewer.watched, isNull);
  });

  testWidgets('original numeric displays consume ROS samples', (tester) async {
    final viewer = TestRosViewer();
    addTearDown(viewer.dispose);
    const key = (name: '/speed', type: 'std_msgs/msg/Float64');
    for (final style in [
      TopicWidgetStyle.graph,
      TopicWidgetStyle.numberBar,
      TopicWidgetStyle.radialGauge,
    ]) {
      final model = style.createModel(key.name, {});
      await tester.pumpWidget(
        ui.MaterialApp(
          home: ui.Scaffold(
            body: Center(
              child: SizedBox(
                width: 384,
                height: 300,
                child: RosTopicValue(
                  viewer: viewer,
                  topic: key,
                  fieldPath: '',
                  model: model,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      );
      viewer.sample.value = RosSample('number', data: {'data': 0.5});
      await tester.pump(const Duration(milliseconds: 100));
      expect(model.subscription.value, 0.5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    }
  });

  testWidgets('selects a discovered topic and renders its changing data', (
    tester,
  ) async {
    final viewer = TestRosViewer();
    addTearDown(viewer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RosGraph(viewer: viewer)),
      ),
    );

    viewer.updateGraph(
      ['/imu_source', '/imu_sink'],
      [
        RosTopic.fromJson({
          'name': '/imu',
          'types': ['sensor_msgs/msg/Imu'],
          'publishers': ['/imu_source'],
          'subscribers': ['/imu_sink'],
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Nodes (2)'), findsOneWidget);
    expect(find.text('/imu_source'), findsOneWidget);
    expect(find.text('/imu_sink'), findsOneWidget);
    await tester.tap(find.text('/imu'));
    await tester.pumpAndSettle();
    expect(viewer.watched, (name: '/imu', type: 'sensor_msgs/msg/Imu'));

    viewer.sample.value = const RosSample('{"orientation":{"z":0.708}}');
    await tester.pump();
    expect(find.textContaining('0.708'), findsOneWidget);

    viewer.updateGraph([], []);
    await tester.pumpAndSettle();
    expect(find.text('Nodes (0)'), findsOneWidget);
    expect(find.text('Topic is no longer available.'), findsOneWidget);
    expect(find.textContaining('0.708'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    expect(viewer.watched, isNull);
  });
}
