import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/ros_viewer.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ROS widgets and list layouts survive layout serialization', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final viewer = RosViewer();
    final grid = TabGridModel(
      rosViewer: viewer,
      preferences: preferences,
      onAddWidgetPressed: () {},
    );
    final topic = grid.createRosTopic((
      name: '/imu',
      type: 'sensor_msgs/msg/Imu',
    ));
    grid.addWidget(topic);
    grid.addWidget(grid.createListLayout(children: [grid.createRosViewer()]));

    final restored = TabGridModel.fromJson(
      rosViewer: viewer,
      preferences: preferences,
      jsonData: grid.toJson(),
      onAddWidgetPressed: () {},
    );

    final restoredWidget = (restored.toJson()['containers'] as List).single;
    expect(restoredWidget['topic'], '/imu');
    expect(restoredWidget['message_type'], 'sensor_msgs/msg/Imu');
    expect(restored.toJson(), grid.toJson());
    restored.dispose();
    grid.dispose();
    viewer.dispose();
  });

  test('unsupported widgets in older layouts are skipped', () async {
    SharedPreferences.setMockInitialValues({});
    final viewer = RosViewer();
    final grid = TabGridModel.fromJson(
      rosViewer: viewer,
      preferences: await SharedPreferences.getInstance(),
      jsonData: {
        'containers': [
          {'type': 'Legacy widget'},
        ],
        'layouts': [
          {
            'type': 'List Layout',
            'title': 'Saved list',
            'children': [
              {'type': 'Legacy widget'},
            ],
          },
        ],
      },
      onAddWidgetPressed: () {},
    );
    final saved = grid.toJson();
    expect(saved['containers'], isEmpty);
    expect((saved['layouts'] as List).single['title'], 'Saved list');
    expect((saved['layouts'] as List).single['children'], isEmpty);
    grid.dispose();
    viewer.dispose();
  });
}
