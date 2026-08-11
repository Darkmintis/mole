# Mole example

Minimal demo for [`mole`](https://pub.dev/packages/mole).

## Run

```bash
cd example
flutter run
```

## What it shows

Three buttons that write sample values into three storage backends:

| Button | Backend | What it demos |
|--------|---------|----------------|
| **SharedPreferences** | `prefs.setString/Int/Bool/Double/StringList` | Raw visibility of each type |
| **Hive box** | `box.put` (Map / String / int) | Live-updating source via box watch |
| **Secure Storage** | `storage.write` tokens | Values **masked by default** in Mole - tap the eye to reveal |

Open the Mole bubble after each tap to inspect, edit, or clear the stored data.