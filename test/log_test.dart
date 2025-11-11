import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:log/log.dart';

class _CaptureListener implements LogMessageListener {
  final List<Map<String, String>> captured = [];
  @override
  void onLogReport(List<Map<String, String>> logMessages) {
    captured.addAll(logMessages);
  }
}

void main() {
  setUp(() {
    LogManager().dispose();
    LogManager()._listener.clear();
    LogManager()._logQueue.clear();
    LogManager().logLevel = LogLevel.info; // ignore < info by default
  });

  test('logs with force=true bypass log level filter', () async {
    final listener = _CaptureListener();
    LogManager().addLogMessageListener(listener);

    _Logger().logD('debug should pass with force', tag: 'T', force: true);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(listener.captured.any((e) => e['text']!.contains('debug should pass with force')), isTrue);
  });

  test('logs are filtered by level when force is not set', () async {
    final listener = _CaptureListener();
    LogManager().addLogMessageListener(listener);

    _Logger().logD('debug should be filtered', tag: 'T');

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(listener.captured.any((e) => e['text']!.contains('debug should be filtered')), isFalse);
  });

  test('listener receives batched logs with metadata', () async {
    final listener = _CaptureListener();
    LogManager().addLogMessageListener(listener);

    _Logger().logI('hello', tag: 'T');
    _Logger().logW('warn', tag: 'T');

    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(listener.captured, isNotEmpty);
    final first = listener.captured.first;
    expect(first.containsKey('text'), isTrue);
    expect(first.containsKey('priority'), isTrue);
  });
}
