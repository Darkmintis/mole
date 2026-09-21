import 'package:flutter/widgets.dart';

/// Configuration for [Mole.install].
///
/// Copy this pattern into your app (e.g. `lib/mole_config.dart`) and adjust
/// the values once - then pass it to [Mole.install].
///
/// ```dart
/// // lib/mole_config.dart
/// import 'package:mole/mole.dart';
///
/// const moleConfig = MoleConfig(
///   enabled: true,
///   enableInRelease: false,
/// );
/// ```
///
/// ### When is Mole active?
///
/// | Build mode | Active when |
/// |---|---|
/// | Debug / Profile | [enabled] is `true` (default) |
/// | Release | [enabled] **and** [enableInRelease] are both `true` |
///
/// Set [enabled] to `false` to turn Mole off entirely - no bubble, no
/// inspection, zero overhead.
///
/// ### Release warning
///
/// When Mole is active in a release build, a console banner and a permanent
/// red **MOLE ACTIVE** tag are always shown. There is no warning when Mole is
/// off in release.
class MoleConfig {
  /// Master switch. When `false`, Mole is a no-op in every build mode.
  ///
  /// Set this to `false` to hide the floating bubble and disable inspection.
  final bool enabled;

  /// Opt-in to run in release builds. Default `false`.
  ///
  /// Has no effect unless [enabled] is also `true`. When both are `true` in a
  /// release build, Mole runs and always shows the release warning.
  final bool enableInRelease;

  /// Minimum gap between UI refreshes while a source is being written to
  /// rapidly. Prevents rebuilding on every single write in a tight loop.
  final Duration refreshDebounce;

  /// Total cache size (across all [MoleCacheSource] directories) in MB that,
  /// when exceeded, shows a small red warning dot on the floating bubble.
  final int cacheSizeWarningThresholdMB;

  /// Optional navigator key for [MaterialApp.router] / GoRouter.
  ///
  /// Pass your app's existing key (the same one given to GoRouter). When null,
  /// Mole uses its built-in [Mole.navigatorKey].
  final GlobalKey<NavigatorState>? navigatorKey;

  const MoleConfig({
    this.enabled = true,
    this.enableInRelease = false,
    this.refreshDebounce = const Duration(milliseconds: 200),
    this.cacheSizeWarningThresholdMB = 50,
    this.navigatorKey,
  });

  /// Mole fully off - no bubble, no listeners, zero overhead.
  static const disabled = MoleConfig(enabled: false);

  MoleConfig copyWith({
    bool? enabled,
    bool? enableInRelease,
    Duration? refreshDebounce,
    int? cacheSizeWarningThresholdMB,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return MoleConfig(
      enabled: enabled ?? this.enabled,
      enableInRelease: enableInRelease ?? this.enableInRelease,
      refreshDebounce: refreshDebounce ?? this.refreshDebounce,
      cacheSizeWarningThresholdMB:
          cacheSizeWarningThresholdMB ?? this.cacheSizeWarningThresholdMB,
      navigatorKey: navigatorKey ?? this.navigatorKey,
    );
  }

  @override
  String toString() {
    return 'MoleConfig('
        'enabled: $enabled, '
        'enableInRelease: $enableInRelease, '
        'refreshDebounce: $refreshDebounce, '
        'cacheSizeWarningThresholdMB: $cacheSizeWarningThresholdMB, '
        'navigatorKey: ${navigatorKey != null}'
        ')';
  }
}
