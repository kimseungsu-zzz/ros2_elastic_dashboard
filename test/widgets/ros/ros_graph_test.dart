import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/widgets/ros/ros_graph.dart';

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
