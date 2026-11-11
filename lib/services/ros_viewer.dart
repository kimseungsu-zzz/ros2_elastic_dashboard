import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as path;

typedef RosTopicKey = ({String name, String type});

class RosTopic {
  final String name;
  final List<String> types;
  final List<String> publishers;
  final List<String> subscribers;

  RosTopic.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      types = List<String>.from(json['types']),
      publishers = List<String>.from(json['publishers']),
      subscribers = List<String>.from(json['subscribers']);
}

class RosSample {
  final String text;
  final bool isError;
  final Object? data;

  const RosSample(this.text, {this.isError = false, this.data});
}

class RosViewer extends ChangeNotifier {
  List<String> nodes = const [];
  List<RosTopic> topics = const [];
  String status = 'Connecting to ROS 2…';
  bool ready = false;

  final Map<RosTopicKey, ({ValueNotifier<RosSample?> value, int count})>
  _subscriptions = {};
  Process? _process;
  bool _starting = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_starting || _process != null || _disposed) return;
    if (kIsWeb) {
      status = 'ROS 2 discovery requires the desktop app.';
      notifyListeners();
      return;
    }

    _starting = true;
    status = 'Connecting to ROS 2…';
    notifyListeners();

    try {
      final script = await rootBundle.loadString('ros/viewer.py');
      final executable = await _pythonExecutable();
      final process = await Process.start(executable, ['-u', '-c', script]);
      if (_disposed) {
        process.kill();
        return;
      }

      _process = process;
      String? lastError;
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) lastError = line;
          });
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleEvent,
            onError: (Object error) {
              lastError = error.toString();
              process.kill();
            },
          );
      unawaited(
        process.stdin.done.then<void>(
          (_) {},
          onError: (Object error) {
            lastError = error.toString();
          },
        ),
      );
      unawaited(
        process.exitCode.then((code) {
          if (_disposed) return;
          _process = null;
          ready = false;
          nodes = const [];
          topics = const [];
          for (final entry in _subscriptions.values) {
            entry.value.value = null;
          }
          status =
              'ROS 2 viewer stopped ($code). '
              '${lastError ?? 'Check the ROS 2 environment and retry.'}';
          notifyListeners();
        }),
      );
    } on Exception catch (error) {
      if (_disposed) return;
      status = 'Could not start ROS 2 viewer. $error';
      notifyListeners();
    } finally {
      _starting = false;
    }
  }

  Future<String> _pythonExecutable() async {
    final environment = Platform.environment;
    final override = environment['ELASTIC_ROS_PYTHON'];
    if (override != null && override.isNotEmpty) return override;
    if (Platform.isWindows) return 'python';

    // Nix ROS environments may have their own Python beside the ROS CLI.
    for (final directory in (environment['PATH'] ?? '').split(':')) {
      if (directory.isEmpty) continue;
      final cli = File(path.join(directory, 'ros2'));
      if (!await cli.exists()) continue;
      try {
        final prefix = path.dirname(await cli.resolveSymbolicLinks());
        final python = File(path.join(prefix, 'python3'));
        if (await python.exists()) return python.path;
      } on FileSystemException {
        // The CLI may disappear if its environment is being updated.
      }
      break;
    }
    return 'python3';
  }

  void _handleEvent(String line) {
    if (_disposed || _process == null) return;
    final Map<String, dynamic> event;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return;
      event = decoded;
    } on FormatException {
      return;
    }
    switch (event['event']) {
      case 'ready':
        ready = true;
        status = 'ROS 2 · DDS domain ${event['domain']}';
        for (final key in _subscriptions.keys) {
          _send('subscribe', key);
        }
        notifyListeners();
      case 'graph':
        nodes = List<String>.from(event['nodes']);
        topics = (event['topics'] as List)
            .map((topic) => RosTopic.fromJson(topic as Map<String, dynamic>))
            .toList();
        for (final entry in _subscriptions.entries) {
          if (!topics.any(
            (topic) =>
                topic.name == entry.key.name &&
                topic.types.contains(entry.key.type) &&
                topic.publishers.isNotEmpty,
          )) {
            entry.value.value.value = null;
          }
        }
        notifyListeners();
      case 'sample':
      case 'topic_error':
        final key = (
          name: event['topic'] as String,
          type: event['type'] as String,
        );
        final error = event['event'] == 'topic_error';
        _subscriptions[key]?.value.value = RosSample(
          error
              ? 'Cannot read ${key.type}: ${event['message']}'
              : const JsonEncoder.withIndent('  ').convert(event['data']),
          isError: error,
          data: event['data'],
        );
    }
  }

  ValueNotifier<RosSample?> watchTopic(RosTopicKey key) {
    final existing = _subscriptions[key];
    if (existing != null) {
      _subscriptions[key] = (value: existing.value, count: existing.count + 1);
      return existing.value;
    }
    final value = ValueNotifier<RosSample?>(null);
    _subscriptions[key] = (value: value, count: 1);
    if (ready) _send('subscribe', key);
    return value;
  }

  void unwatchTopic(RosTopicKey key) {
    final existing = _subscriptions[key];
    if (existing == null) return;
    if (existing.count > 1) {
      _subscriptions[key] = (value: existing.value, count: existing.count - 1);
    } else {
      _subscriptions.remove(key);
      existing.value.dispose();
      if (ready) _send('unsubscribe', key);
    }
  }

  void _send(String action, RosTopicKey key) {
    _process?.stdin.writeln(
      jsonEncode({
        'action': action,
        'topic': key.name,
        'type': key.type,
      }),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _process?.kill();
    for (final entry in _subscriptions.values) {
      entry.value.dispose();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
