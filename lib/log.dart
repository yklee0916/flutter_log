import 'dart:async';
import 'package:flutter/foundation.dart';

/// Lightweight logging utilities for Flutter SDKs/apps.
///
/// - Supports level-based filtering
/// - Batched dispatch to listeners (100ms)
/// - `force: true` to bypass filters
/// - Mixin and static helper APIs

enum LogLevel {
  verbose('V'),
  debug('D'),
  info('I'),
  warning('W'),
  error('E'),
  none('N');

  const LogLevel(this._context);

  /// Single-letter code used in payloads (private storage)
  final String _context;

  /// Alias for [context] to mirror 'rawValue' naming style.
  String get rawValue => _context;

  /// Factory-style lookup by raw value. Defaults to LogLevel.none if not found.
  factory LogLevel.getByRawValue(String raw) {
    return LogLevel.values.firstWhere((level) => level.rawValue == raw, orElse: () => LogLevel.none);
  }

  /// Numerical priority used for comparisons.
  int priority() {
    switch (this) {
      case LogLevel.verbose:
        return 1;
      case LogLevel.debug:
        return 2;
      case LogLevel.info:
        return 3;
      case LogLevel.warning:
        return 4;
      case LogLevel.error:
        return 5;
      case LogLevel.none:
        return 8;
    }
  }
}

/// Listener for batched logs emitted by [LogManager].
abstract mixin class LogMessageListener {
  void onLogReport(List<Map<String, String>> logMessages) {}
}

/// Central manager for logging configuration and dispatch.
class LogManager with Logger {
  LogLevel _logLevel = LogLevel.none;
  LogLevel get logLevel => _logLevel;
  set logLevel(LogLevel value) {
    if (_logLevel == value) return;
    _logLevel = value;
    logW("set logLevel: $value");
  }

  final List<Map<String, String>> _logQueue = [];

  final List<LogMessageListener> _listener = [];
  void notifyLogMessage(List<Map<String, String>> logMessages) {
    for (var listener in _listener) {
      listener.onLogReport(logMessages);
    }
  }

  void addLogMessageListener(LogMessageListener listener) {
    bool alreadyAdded = false;
    for (LogMessageListener l in _listener) {
      if (l == listener) {
        alreadyAdded = true;
        break;
      }
    }
    if (alreadyAdded) return;
    _listener.add(listener);
  }

  void removeLogMessageListener(LogMessageListener listener) {
    _listener.remove(listener);
  }

  /// Set minimum log level.
  void setMinimumLogLevel(LogLevel level) {
    if (level == logLevel) return;
    logLevel = level;
  }

  LogManager._privateConstructor();

  static final LogManager _instance = LogManager._privateConstructor();

  factory LogManager() {
    return _instance;
  }

  @override
  get logTag => "LogManager";

  bool _isRunning = false;
  Timer? _timer;

  /// Stop any scheduled dispatch.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleDispatchIfNeeded() {
    if (_timer != null) return;
    _timer = Timer(const Duration(milliseconds: 100), () async {
      _timer = null; // clear scheduled flag first
      if (_isRunning) return;
      await _processLogQueue();
    });
  }

  Future<void> _processLogQueue() async {
    if (_logQueue.isEmpty) return;
    _isRunning = true;
    try {
      List<Map<String, String>> queue = [];
      for (Map<String, String> data in _logQueue) {
        queue.add(Map.from(data));
      }
      _logQueue.removeRange(0, queue.length);

      notifyLogMessage(queue);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isRunning = false;
      // If more logs arrived during processing, schedule again
      if (_logQueue.isNotEmpty && _timer == null) {
        _scheduleDispatchIfNeeded();
      }
    }
  }
}

/// Mixin that provides logging helpers bound to [logTag].
mixin Logger {
  final _fileNameRegExp = RegExp(r'^#3.*?/([^/]*?\.dart)', multiLine: true);
  final _lineNumberRegExp = RegExp(r'^#3[ \t]+.+:(?<line>[0-9]+):[0-9]+\)$', multiLine: true);

  /// Identifier to be included in emitted log records.
  String get logTag => "";

  /// Generic log method.
  void log(Object msg, {required LogLevel level, String? tag, bool? force}) {
    _log(msg, priority: level, tag: tag, force: force);
  }

  /// Convenience variants for each level.
  void logV(Object msg, {String? tag, bool? force}) {
    _log(msg, priority: LogLevel.verbose, tag: tag, force: force);
  }

  void logD(Object msg, {String? tag, bool? force}) {
    _log(msg, priority: LogLevel.debug, tag: tag, force: force);
  }

  void logI(Object msg, {String? tag, bool? force}) {
    _log(msg, priority: LogLevel.info, tag: tag, force: force);
  }

  void logW(Object msg, {StackTrace? stackTrace, String? tag, bool? force}) {
    _log(msg, priority: LogLevel.warning, stackTrace: stackTrace, tag: tag, force: force);
  }

  void logE(Object msg, {StackTrace? stackTrace, String? tag, bool? force}) {
    _log(msg, priority: LogLevel.error, stackTrace: stackTrace, tag: tag, force: force);
  }

  String? get _fileName {
    final match = _fileNameRegExp.firstMatch(StackTrace.current.toString());
    return match?.group(1);
  }

  int get _lineNumber {
    final match = _lineNumberRegExp.firstMatch(StackTrace.current.toString());
    return int.parse(match?.namedGroup('line') ?? "-1");
  }

  _log(Object msg, {StackTrace? stackTrace, LogLevel priority = LogLevel.debug, String? tag, bool? force}) {
    // No listeners → skip
    if (LogManager()._listener.isEmpty) return;

    // Early-exit on level filtering to avoid string building costs
    if (force != true && LogManager().logLevel.priority() > priority.priority()) return;

    StringBuffer log = StringBuffer();

    if (kDebugMode) {
      log.write("[${_fileName}:${_lineNumber}]");
    } else if (tag != null && tag.isNotEmpty) {
      log.write("[$tag]");
    } else if (logTag.isNotEmpty) {
      log.write("[$logTag]");
    }

    String m = msg.toString().replaceAll("\n", " ");
    if (!kDebugMode) {
      m = m.replaceAll(RegExp(r"\s+"), " ");
    }
    log.write(" $m");

    String str = log.toString();

    LogManager().addLogQueue(str, raw: m, priority: priority, force: force);
    if (stackTrace != null) {
      final trace = stackTrace.toString();
      LogManager().addLogQueue("${str.replaceAll(" $m", "")} $trace", raw: trace, priority: priority);
    }
  }
}

/// Extension for queueing log payloads.
extension LogManagerExtension on LogManager {
  void addLogQueue(String text, {String? raw, LogLevel? priority, bool? force}) {
    try {
      Map<String, String> data = {
        'text': text,
        'force': force == true ? "1" : "0",
        'raw': raw ?? "",
        'priority': priority?.rawValue ?? "",
        'timestamp': "${DateTime.now().millisecondsSinceEpoch}",
      };
      _logQueue.add(data);
      _scheduleDispatchIfNeeded();
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}

// Static helpers removed: prefer using Logger mixin directly on your classes.
