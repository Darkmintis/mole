# Changelog

All notable changes to this project will be documented in this file.

## [0.1.3]

### Fixed

- pub.dev analysis: remove broken `.pubignore` that overrode `.gitignore`
  and published local `build/` artifacts.

## [0.1.2]

### Changed

- Loosen `flutter_secure_storage` to `>=9.2.4 <12.0.0` — no longer forces
  FSS 11 or Android SDK 37 on existing apps.
- Add optional `package:mole/secure_storage.dart` import for secure storage
  adapters (`MoleSecureStorageSource` is no longer exported from
  `package:mole/mole.dart`).
- Document secure storage import in README.

## [0.1.1]

### Changed

- Upgrade `flutter_secure_storage` to ^11.0.0

## [0.1.0]

### Added

- Initial release: local storage inspector for Flutter.
- Built-in source adapters for SharedPreferences, Hive, and Secure Storage.
- Floating bubble + Material 3 dashboard grouped by source with live counts.
- Per-entry edit/delete, clear per source with confirmation, search by key.
- Secure Storage values masked by default (tap to reveal).
- Production-safe install gating: off by default in release with an
  unmissable warning when explicitly enabled.
