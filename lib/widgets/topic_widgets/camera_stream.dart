import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/camera_stream_controller.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/topic_widgets/topic_widget.dart';
import 'package:elastic_dashboard/widgets/whep.dart';

enum CameraStreamType {
  whep('whep:', 'WebRTC'),
  mjpeg('mjpg:', 'MJPG');

  const CameraStreamType(this.prefix, this.displayName);

  final String prefix;
  final String displayName;

  static CameraStreamType? fromName(String name) =>
      values.firstWhereOrNull((e) => e.name == name);

  static CameraStreamType? fromUrl(String url) {
    for (final type in values) {
      if (url.startsWith(type.prefix)) {
        return type;
      }
    }
    return null;
  }
}

class CameraStreamModel extends TopicWidgetModel {
  int? quality;
  int? fps;
  Size? resolution;
  int _rotationTurns = 0;

  CameraStreamType? selectedStreamType;

  CameraStreamController? controller;

  Iterable<String> get streams => switch (subscription.value) {
    final String url => [url],
    final List items => items.whereType<String>(),
    _ => const [],
  };

  CameraStreamType get activeStreamType =>
      selectedStreamType ??
      streams
          .map((url) => CameraStreamType.fromUrl(url))
          .whereType<CameraStreamType>()
          .firstOrNull ??
      CameraStreamType.mjpeg;

  List<String> getStreamsOfType(CameraStreamType type) => [
    for (final url in streams)
      if (CameraStreamType.fromUrl(url) == type)
        url.substring(type.prefix.length)
      else if (CameraStreamType.fromUrl(url) == null &&
          Uri.tryParse(url)?.hasAuthority == true)
        url,
  ];

  int get rotationTurns => _rotationTurns;

  set rotationTurns(int value) {
    _rotationTurns = value;
    notifyListeners();
  }

  String getUrlWithParameters(String urlString) {
    Uri url = Uri.parse(urlString);

    Map<String, String> parameters = Map<String, String>.from(
      url.queryParameters,
    );

    parameters.addAll({
      if (resolution != null &&
          resolution!.width != 0.0 &&
          resolution!.height != 0.0)
        'resolution':
            '${resolution!.width.floor()}x${resolution!.height.floor()}',
      if (fps != null) 'fps': '$fps',
      if (quality != null) 'compression': '$quality',
    });

    return url.replace(queryParameters: parameters).toString();
  }

  CameraStreamModel.fromJson(super.topic, Map<String, dynamic> jsonData) {
    quality = tryCast(jsonData['compression']);
    fps = tryCast(jsonData['fps']);
    _rotationTurns = tryCast(jsonData['rotation_turns']) ?? 0;

    String? streamTypeString = tryCast(jsonData['stream_type']);
    if (streamTypeString != null) {
      selectedStreamType = CameraStreamType.fromName(streamTypeString);
    }

    List<num>? resolution = tryCast<List<Object?>>(
      jsonData['resolution'],
    )?.whereType<num>().toList();

    if (resolution != null && resolution.length > 1) {
      if (resolution[0] % 2 != 0) {
        resolution[0] += 1;
      }
      if (resolution[0] > 0 && resolution[1] > 0) {
        this.resolution = Size(
          resolution[0].toDouble(),
          resolution[1].toDouble(),
        );
      }
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'rotation_turns': rotationTurns,
    'compression': ?quality,
    'fps': ?fps,
    if (resolution != null)
      'resolution': [resolution!.width, resolution!.height],
    'stream_type': ?selectedStreamType?.name,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          const Text('Stream Type:'),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButton<CameraStreamType?>(
              isExpanded: true,
              value: selectedStreamType,
              items: [
                const DropdownMenuItem<CameraStreamType?>(
                  value: null,
                  child: Text('Auto'),
                ),
                for (final type in CameraStreamType.values)
                  DropdownMenuItem<CameraStreamType?>(
                    value: type,
                    child: Text(
                      type.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                CameraStreamType previousActive = activeStreamType;
                setState(() => selectedStreamType = value);

                if (previousActive != activeStreamType) {
                  // Fixed reactivity
                  notifyListeners();
                  closeClient();
                  refresh();
                }
              },
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 5),
    ListenableBuilder(
      listenable: Listenable.merge([this, subscription]),
      builder: (context, _) =>
          Column(children: _editFieldsFor(activeStreamType)),
    ),
  ];

  List<Widget> _editFieldsFor(CameraStreamType type) => switch (type) {
    CameraStreamType.whep => _whepEditFields(),
    CameraStreamType.mjpeg => _mjpegEditFields(),
  };

  List<Widget> _whepEditFields() => _rotationFields();

  List<Widget> _mjpegEditFields() => [
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: fps?.toString() ?? '-1',
              label: 'FPS',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newFPS = int.tryParse(value);

                setState(() {
                  if (newFPS == -1 || newFPS == 0) {
                    fps = null;
                    return;
                  }

                  fps = newFPS;
                });
              },
            ),
          ),
          const SizedBox(width: 10.0),
          const Text('Resolution'),
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: resolution?.width.floor().toString() ?? '-1',
              label: 'Width',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newWidth = int.tryParse(value);

                setState(() {
                  if (newWidth == null || newWidth == 0) {
                    resolution = null;
                    return;
                  }

                  if (newWidth! % 2 != 0) {
                    // Won't allow += for some reason
                    newWidth = newWidth! + 1;
                  }

                  resolution = Size(
                    newWidth!.toDouble(),
                    resolution?.height.toDouble() ?? 0,
                  );
                });
              },
            ),
          ),
          const Text('x'),
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: resolution?.height.floor().toString() ?? '-1',
              label: 'Height',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newHeight = int.tryParse(value);

                setState(() {
                  if (newHeight == null || newHeight == 0) {
                    resolution = null;
                    return;
                  }

                  resolution = Size(
                    resolution?.width.toDouble() ?? 0,
                    newHeight.toDouble(),
                  );
                });
              },
            ),
          ),
        ],
      ),
    ),
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          const Text('Quality:'),
          Expanded(
            child: Slider(
              value: quality?.toDouble() ?? -5.0,
              min: -5.0,
              max: 100.0,
              divisions: 105,
              label: '${quality ?? -1}',
              onChanged: (value) {
                setState(() {
                  if (value < 0) {
                    quality = null;
                  } else {
                    quality = value.floor();
                  }
                });
              },
            ),
          ),
        ],
      ),
    ),
    TextButton(
      onPressed: () => refresh(),
      child: const Text('Apply Quality Settings'),
    ),
    ..._rotationFields(),
  ];

  List<Widget> _rotationFields() => [
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Left'),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
              onPressed: () {
                int newRotation = rotationTurns - 1;
                if (newRotation < 0) {
                  newRotation += 4;
                }
                rotationTurns = newRotation;
              },
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Right'),
              icon: const Icon(Icons.rotate_90_degrees_cw),
              onPressed: () {
                int newRotation = rotationTurns + 1;
                if (newRotation >= 4) {
                  newRotation -= 4;
                }
                rotationTurns = newRotation;
              },
            ),
          ),
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    closeClient();
    super.dispose();
  }

  void closeClient() {
    controller?.dispose();
    controller = null;
  }
}

class CameraStreamWidget extends TopicWidget {
  static const String widgetType = 'Camera Stream';

  const CameraStreamWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CameraStreamModel model = cast(context.watch<TopicWidgetModel>());

    return ListenableBuilder(
      listenable: model.subscription,
      builder: (context, child) {
        final activeType = model.activeStreamType;
        final urls = model.getStreamsOfType(activeType);

        if (activeType == CameraStreamType.whep && urls.isNotEmpty) {
          return _buildWhepStream(model, urls);
        } else {
          return _buildMjpegStream(
            model,
            activeType == CameraStreamType.mjpeg ? urls : [],
          );
        }
      },
    );
  }

  Widget _buildWhepStream(CameraStreamModel model, List<String> whepStreams) {
    if (model.controller is MjpegController) {
      model.controller!.dispose();
      model.controller = null;
    }

    bool createNewWhep =
        model.controller is! WhepController ||
        !model.controller!.streams.equals(whepStreams);

    if (createNewWhep) {
      model.controller?.dispose();
      model.controller = WhepController(
        streams: whepStreams,
        timeout: const Duration(milliseconds: 500),
      );
    }

    final whepCtrl = model.controller as WhepController;
    return IntrinsicWidth(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMetricsRow(whepCtrl),
          Flexible(
            child: Whep(
              controller: whepCtrl,
              quarterTurns: model.rotationTurns,
            ),
          ),
          const Text(''),
        ],
      ),
    );
  }

  Widget _buildMjpegStream(CameraStreamModel model, List<String> mjpegStreams) {
    if (model.controller is WhepController) {
      model.controller!.dispose();
      model.controller = null;
    }

    if (mjpegStreams.isEmpty) {
      model.closeClient();
      return _buildWaitingScreen();
    }

    bool createNewWidget = model.controller is! MjpegController;

    List<String> streamUrls = mjpegStreams
        .map((stream) => model.getUrlWithParameters(stream))
        .toList();

    createNewWidget =
        createNewWidget ||
        !(model.controller?.streams.equals(streamUrls) ?? false);

    if (createNewWidget) {
      model.controller?.dispose();

      model.controller = MjpegController(
        streams: streamUrls,
        timeout: const Duration(milliseconds: 500),
      );
    }

    final mjpegCtrl = model.controller as MjpegController;
    return IntrinsicWidth(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMetricsRow(mjpegCtrl),
          Flexible(
            child: Mjpeg(
              controller: mjpegCtrl,
              fit: BoxFit.contain,
              expandToFit: true,
              quarterTurns: model.rotationTurns,
            ),
          ),
          const Text(''),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      CustomLoadingIndicator(),
      const SizedBox(height: 10),
      const Text(
        'Waiting for Camera Stream connection...',
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _buildMetricsRow(CameraStreamController controller) => Row(
    children: [
      ValueListenableBuilder(
        valueListenable: controller.framesPerSecond,
        builder: (context, value, child) => Text('FPS: $value'),
      ),
      const Spacer(),
      ValueListenableBuilder(
        valueListenable: controller.bandwidth,
        builder: (context, value, child) =>
            Text('Bandwidth: ${value.toStringAsFixed(2)} Mbps'),
      ),
    ],
  );
}
