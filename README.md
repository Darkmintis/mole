# Mole

Local storage inspector for Flutter. Pass the storage instances your app already uses, get a floating bubble in debug, and inspect, edit, or delete stored values.

[![pub package](https://img.shields.io/pub/v/mole.svg)](https://pub.dev/packages/mole)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Install

```yaml
dependencies:
  mole: ^0.1.3
```

```bash
flutter pub get
```

## Setup

### 1. Add config

Create `lib/mole_config.dart`:

```dart
import 'package:mole/mole.dart';

const moleConfig = MoleConfig(
  enabled: true,          // false = hide bubble, Mole does nothing
  enableInRelease: false, // keep false for production
);
```

### 2. Install in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:mole/mole.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mole_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  Mole.install(
    config: moleConfig,
    sources: [
      MoleSharedPrefsSource(prefs),
      // Add only what your app uses:
      // MoleHiveSource(box),
      // MoleSecureStorageSource(storage)  — import package:mole/secure_storage.dart
      // MoleCacheSource(),
    ],
    onStorageChanged: () {
      // Optional: reload your UI when Mole edits storage.
    },
  );

  runApp(const MyApp());
}
```

### 3. Attach to `MaterialApp`

```dart
MaterialApp(
  navigatorKey: Mole.navigatorKey,
  builder: Mole.builder,
  home: const HomePage(),
)
```

Tap the floating bubble to open the inspector.

### MaterialApp.router / GoRouter

Wire Mole's key to the router (same idea as `MaterialApp.navigatorKey`):

```dart
final router = GoRouter(
  navigatorKey: Mole.navigatorKey,
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
  ],
);

MaterialApp.router(
  routerConfig: router,
  builder: Mole.builder,
);
```

If your app already owns a `GlobalKey<NavigatorState>`, pass it in:

```dart
Mole.install(
  config: MoleConfig(navigatorKey: yourNavKey),
  sources: [/* … */],
);
// GoRouter(navigatorKey: yourNavKey, …)
```

## Config

| Option | Default | Description |
|---|---|---|
| `enabled` | `true` | Master switch. `false` turns Mole off completely. |
| `enableInRelease` | `false` | Allow Mole in release builds. Shows a console warning and red **MOLE ACTIVE** tag. |
| `navigatorKey` | `null` | Optional app-owned key for GoRouter. Falls back to [Mole.navigatorKey]. |

| Build | Mole runs when |
|---|---|
| Debug / profile | `enabled: true` |
| Release | `enabled: true` and `enableInRelease: true` |

## Sources

Register only the storage your app already created. Only registered sources appear in Mole.

| Adapter | Backend |
|---|---|
| `MoleSharedPrefsSource(prefs)` | SharedPreferences |
| `MoleHiveSource(box)` | Hive box |
| `MoleSecureStorageSource(storage)` | flutter_secure_storage — `import 'package:mole/secure_storage.dart'` |
| `MoleCacheSource()` | App temp/cache files |

Pass the same instances your app already uses (supports FSS 9–11). Edits write through immediately — use `onStorageChanged` to refresh your UI.

## What you get

- Floating solid bubble (48×48, lower-middle by default) — drag snaps to an edge
- Remembers position; long-press hides until hot reload / hot restart
- Hidden while the inspector is open
- Dashboard grouped by source with live entry counts
- View, edit, delete, and clear per key or per source
- Search by key or value
- Off by default in release unless you opt in

## Example app

```bash
git clone https://github.com/darkmintis/mole.git
cd mole/example
flutter run
```

## Requirements

- Flutter `>=3.44.0`
- Dart `^3.12.1`

## Roadmap

See [TODO.md](TODO.md) for the public backlog and release plan.

## License

MIT © Darkmintis
