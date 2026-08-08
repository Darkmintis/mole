# Mole

Local storage inspector for Flutter — see, edit, and clear everything your app has stored in **SharedPreferences**, **Hive**, **Secure Storage**, and more.

**See everything. Ship nothing you didn't mean to.**

[![pub package](https://img.shields.io/pub/v/mole.svg)](https://pub.dev/packages/mole)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Mole registers the storage instances *you already created* and shows them in a Material 3 inspector: floating bubble, list of sources, live key/value tables, per-entry edit/delete, and clear-all per source.

## Why Mole

Most Flutter storage debuggers make you wire up fake mirrors or read raw files. Mole is different:

| | Typical tools | Mole |
|---|---|---|
| Setup | Adapters, mocks, polling | Register existing instances — zero adapters |
| Sources | Usually one backend | Grouped by source: prefs · Hive · Secure |
| Values | Read-only export | **Inline edit + delete** per key |
| Clear | Manual | **Clear one key, one source, or everything** |
| Release | Usually unavailable or unsafe | **Off by default** (true no-op) |
| Release warning | Often missing | **Always on** — console banner + permanent red tag |

## Install

```yaml
dependencies:
  mole: ^0.1.0
```

```bash
flutter pub get
```

## Quick start

Register the storage instances your app already owns:

```dart
import 'package:mole/mole.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  Mole.install(
    config: const MoleConfig(),
    sources: [
      MoleSharedPrefsSource(prefs),
      // MoleHiveSource(box: myBox),
      // MoleSecureStorageSource(secureStorage),
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: Mole.navigatorKey,
      builder: Mole.builder, // floating bubble
      home: const HomePage(),
    );
  }
}
```

Tap the floating bubble to open the dashboard. Sources are listed with live entry counts; tap one to browse its keys and values.

## Configuration

```dart
Mole.install(
  config: const MoleConfig(
    enabled: true,            // master switch (debug/profile)
    enableInRelease: false,   // set true only when you intentionally need release
    startMinimized: true,
    refreshDebounce: Duration(milliseconds: 200), // batch rapid writes
  ),
  sources: [...],
);
```

### Debug and release behavior

| Mode | Behavior |
|---|---|
| Debug / Profile | On when `enabled: true` (default) |
| Release | **Fully off** unless `enableInRelease: true` |
| Release + `enableInRelease: true` | On, with a loud console warning **and** a permanent red **MOLE ACTIVE** tag |

The release warning is **not configurable**. If Mole is running in a release build, the banner and red tag always appear so storage visibility can never ship silently.

When disabled, Mole attaches nothing and inspects nothing.

## Source adapters

Mole never creates or owns storage instances — pass it the ones you already have.

| Adapter | Storage | Values |
|---|---|---|
| `MoleSharedPrefsSource(prefs)` | `SharedPreferences` | Full raw visibility |
| `MoleHiveSource(box)` | Hive `Box` | Full raw visibility, live via box watch |
| `MoleSecureStorageSource(storage)` | `flutter_secure_storage` | **Masked by default** — tap to reveal |

Secure Storage values are masked in-app because they are real secrets (tokens, credentials) sitting at rest on a device. `SharedPreferences` and Hive values are shown exactly as stored.

## Features (v0.1)

- One-line `Mole.install(config:, sources:)`
- Built-in adapters for SharedPreferences, Hive, Secure Storage
- Floating draggable/minimizable bubble with total entry count
- Dashboard: grouped sources with live entry counts
- Live key/value tables per source
- Per-entry **edit** and **delete**
- Clear a single source with a confirmation dialog
- Search/filter by key or value
- Material 3, auto dark/light theme
- True no-op when disabled

Coming soon (v1.1): Isar adapter, JSON export + share, and clear-everything across all sources with a stronger guard.

## Example

```bash
git clone https://github.com/darkmintis/mole.git
cd mole
fvm use 3.44.1   # or use your Flutter 3.44.1+ SDK
cd example
flutter run
```

The example writes sample values into SharedPreferences, a Hive box, and Secure Storage, then lets you open the Mole bubble to inspect/edit/clear them.

## API surface

```dart
Mole.install(config: ..., sources: [...]);
Mole.addSources([...]);          // register more sources later
Mole.navigatorKey                // attach to MaterialApp
Mole.builder                     // MaterialApp / CupertinoApp builder
Mole.showOverlay(context)        // optional manual overlay
Mole.openDashboard()             // opens inspector
Mole.isActive
```


## Requirements

- Flutter `>=3.44.0`
- Dart `^3.12.1`

## License

MIT © Darkmintis