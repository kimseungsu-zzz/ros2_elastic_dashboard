import 'package:elastic_dashboard/widgets/topic_widgets/accelerometer.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/gyro.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/motor_controller.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/three_axis_accelerometer.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/ultrasonic.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/boolean_box.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/camera_stream.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/graph.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/large_text_display.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/number_bar.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/number_slider.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/radial_gauge.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/single_color_view.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/text_display.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/toggle_button.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/voltage_view.dart';

enum TopicWidgetStyle {
  text(TextDisplay.widgetType),
  largeText(LargeTextDisplay.widgetType),
  booleanBox(BooleanBox.widgetType),
  toggleButton(ToggleButton.widgetType),
  toggleSwitch(ToggleSwitch.widgetType),
  graph(GraphWidget.widgetType, 2),
  numberBar(NumberBar.widgetType),
  numberSlider(NumberSlider.widgetType),
  radialGauge(RadialGaugeWidget.widgetType, 1.6),
  voltage(VoltageView.widgetType),
  gyro(Gyro.widgetType),
  accelerometer(AccelerometerWidget.widgetType),
  acceleration3d(ThreeAxisAccelerometer.widgetType),
  ultrasonic(Ultrasonic.widgetType),
  encoder(EncoderWidget.widgetType),
  motor(MotorController.widgetType),
  singleColor(SingleColorView.widgetType),
  multiColor(MultiColorView.widgetType),
  camera(CameraStreamWidget.widgetType, 2);

  const TopicWidgetStyle(this.label, [this.minCells = 1]);

  final String label;
  final double minCells;

  static TopicWidgetStyle? fromLabel(Object? label) {
    if (label == 'Text View') return text;
    if (label == 'Simple Dial') return radialGauge;
    for (final style in values) {
      if (style.label == label) return style;
    }
    return null;
  }

  static TopicWidgetStyle defaultFor(String messageType) =>
      messageType == 'std_msgs/msg/Bool' ? booleanBox : text;

  TopicWidgetModel createModel(String topic, Map<String, dynamic> properties) =>
      switch (this) {
        booleanBox => BooleanBoxModel.fromJson(topic, properties),
        graph => GraphModel.fromJson(topic, properties),
        numberBar => NumberBarModel.fromJson(topic, properties),
        numberSlider => NumberSliderModel.fromJson(topic, properties),
        radialGauge => RadialGaugeModel.fromJson(topic, properties),
        voltage => VoltageViewModel.fromJson(topic, properties),
        gyro => GyroModel.fromJson(topic, properties),
        camera => CameraStreamModel.fromJson(topic, properties),
        _ => TopicWidgetModel(topic),
      };

  TopicWidget build() => switch (this) {
    text => const TextDisplay(),
    largeText => const LargeTextDisplay(),
    booleanBox => const BooleanBox(),
    toggleButton => const ToggleButton(),
    toggleSwitch => const ToggleSwitch(),
    graph => const GraphWidget(),
    numberBar => const NumberBar(),
    numberSlider => const NumberSlider(),
    radialGauge => const RadialGaugeWidget(),
    voltage => const VoltageView(),
    gyro => const Gyro(),
    accelerometer => const AccelerometerWidget(),
    acceleration3d => const ThreeAxisAccelerometer(),
    ultrasonic => const Ultrasonic(),
    encoder => const EncoderWidget(),
    motor => const MotorController(),
    singleColor => const SingleColorView(),
    multiColor => const MultiColorView(),
    camera => const CameraStreamWidget(),
  };
}
