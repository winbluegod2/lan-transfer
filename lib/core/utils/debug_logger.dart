import 'dart:async';
import 'package:flutter/foundation.dart';

class DebugLogger {
  static final List<String> _logs = [];
  static const _maxLogs = 80;
  static final _controller = StreamController<List<String>>.broadcast();

  static Stream<List<String>> get stream => _controller.stream;
  static List<String> get logs => List.unmodifiable(_logs);

  static void log(String message) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final t =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '$t $message';
    _logs.add(entry);
    if (_logs.length > _maxLogs) _logs.removeAt(0);
    _controller.add(List.unmodifiable(_logs));
    debugPrint('[DBG] $entry');
  }

  static void clear() {
    _logs.clear();
    _controller.add([]);
  }
}
