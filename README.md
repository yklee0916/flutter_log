# flutter_log

Lightweight logging utility for Flutter apps with:
- Pluggable listeners via `LogMessageListener`
- Log level filtering (`verbose` → `error`)
- Force logging that bypasses filters (`force: true`)
- Minimal API surface for easy embedding in SDKs

## Installation

Add to your `pubspec.yaml` as a path or git dependency:

```yaml
dependencies:
  log:
    path: ../flutter_log
```

or

```yaml
dependencies:
  log:
    git:
      url: https://github.com/your-org/flutter_log.git
```

## Quick start

**Important:** By default, log level is set to `LogLevel.none`, so no logs will be emitted until you:
1. Set a minimum log level
2. Add a listener to receive logs

```dart
import 'package:log/log.dart';

class Example with Logger {
  @override
  String get logTag => 'Example';

  void run() {
    // Set minimum log level (required to see logs)
    LogManager().setMinimumLogLevel(LogLevel.info);
    
    // Add a listener to receive logs (required)
    LogManager().addLogMessageListener(MyLogListener());
    
    logI('Started');
    logE('Something went wrong', stackTrace: StackTrace.current, force: true);
  }
}

class MyLogListener implements LogMessageListener {
  @override
  void onLogReport(List<Map<String, String>> logs) {
    for (final log in logs) {
      print('[${log['priority']}] ${log['text']}');
    }
  }
}
```

## API

### Log Levels

- `LogLevel.verbose|debug|info|warning|error|none` (payload code: `V|D|I|W|E|N`)
- **Default:** `LogLevel.none` (no logs emitted until changed)

### Logger Mixin Methods

- `log(Object, level: LogLevel, {tag, force})`
- `logV/D/I/W/E(Object, {tag, force, stackTrace})`

### Static Helpers

- `sLog(Object, level: LogLevel, {tag, force})`
- `sLogV/D/I/W/E(Object, {tag, force, stackTrace})`

### Configuration

- **Set minimum log level:** `LogManager().setMinimumLogLevel(LogLevel.info)`
- **Add listener:** `LogManager().addLogMessageListener(listener)` (required to receive logs)
- **Remove listener:** `LogManager().removeLogMessageListener(listener)`
- **Dispose:** `LogManager().dispose()` (stops scheduled dispatch)

### Listeners

Logs are batched and dispatched every 100ms to registered listeners:

```dart
class MyListener implements LogMessageListener {
  @override
  void onLogReport(List<Map<String, String>> logs) {
    for (final item in logs) {
      // item['text'], item['priority'] (V|D|I|W|E|N), item['force'] ("1" or "0"), item['raw']
    }
  }
}

void setup() {
  LogManager().addLogMessageListener(MyListener());
}
```

## Testing

Run:

```bash
flutter test
```

## License

MIT License. See `LICENSE` for details.
