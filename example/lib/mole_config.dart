import 'package:mole/mole.dart';

/// App-wide Mole settings - edit this file to change inspector behavior.
///
/// Copy this file into your own project and adjust the values below.
const moleConfig = MoleConfig(
  /// Master switch. Set to `false` to hide the bubble and disable Mole.
  enabled: true,

  /// Release opt-in. Keep `false` for production builds unless you
  /// intentionally need storage inspection in release (shows a loud warning).
  enableInRelease: false,

  refreshDebounce: Duration(milliseconds: 200),
  cacheSizeWarningThresholdMB: 50,
);
