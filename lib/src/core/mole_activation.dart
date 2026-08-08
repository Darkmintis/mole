import 'package:flutter/foundation.dart';

import '../config/mole_config.dart';

/// Resolves whether Mole should be active for a given config + build mode.
///
/// Extracted for unit testing without depending on [kReleaseMode] alone.
class MoleActivation {
  const MoleActivation({
    required this.active,
    required this.showReleaseWarning,
  });

  /// Whether sources, store, and overlay should run.
  final bool active;

  /// Whether to print the release banner and show the red on-screen tag.
  ///
  /// Always `true` when Mole is active in a release build. Not configurable.
  final bool showReleaseWarning;

  /// Compute activation from [config] and build mode.
  factory MoleActivation.resolve(MoleConfig config, {bool? isReleaseMode}) {
    final release = isReleaseMode ?? kReleaseMode;

    if (release) {
      if (!config.enableInRelease) {
        return const MoleActivation(active: false, showReleaseWarning: false);
      }
      // Release + explicit opt-in: warning is permanent and cannot be disabled.
      return const MoleActivation(active: true, showReleaseWarning: true);
    }

    // debug / profile
    return MoleActivation(active: config.enabled, showReleaseWarning: false);
  }
}

/// Loud console banner printed once when Mole runs in a release build.
void printMoleReleaseWarning() {
  const banner = '''
╔════════════════════════════════════════════════════╗
║  ⚠️  MOLE IS ACTIVE IN A RELEASE BUILD              ║
║  You explicitly set enableInRelease: true.          ║
║  Real user storage data is visible through Mole     ║
║  on this device. Disable before shipping to users.  ║
╚════════════════════════════════════════════════════╝''';
  debugPrint(banner);
}
