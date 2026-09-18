import 'dart:async';

import 'package:flutter/material.dart';

import 'config/mole_config.dart';
import 'core/mole_activation.dart';
import 'core/mole_engine.dart';
import 'core/mole_store.dart';
import 'sources/mole_source.dart';
import 'ui/mole_bubble.dart';
import 'ui/mole_dashboard.dart';

/// Mole - modern, production-safe local storage inspector for Flutter.
///
/// ```dart
/// void main() {
///   final prefs = await SharedPreferences.getInstance();
///   Mole.install(sources: [MoleSharedPrefsSource(prefs)]);
///   runApp(const MyApp());
/// }
/// ```
class Mole {
  Mole._();

  static MoleConfig _config = const MoleConfig();
  static MoleStore? _store;
  static MoleEngine? _engine;
  static MoleActivation _activation = const MoleActivation(
    active: false,
    showReleaseWarning: false,
  );
  static OverlayEntry? _overlayEntry;
  static bool _installed = false;
  static final ValueNotifier<bool> _inspectorOpen = ValueNotifier<bool>(false);

  /// Attach to [MaterialApp.navigatorKey] so the bubble can open the inspector.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Whether the Mole inspector screen is currently open.
  static bool get isInspectorOpen => _inspectorOpen.value;

  /// Whether Mole is currently inspecting storage.
  static bool get isActive => _activation.active;

  /// Whether the permanent release warning tag should be shown.
  static bool get showReleaseWarning => _activation.showReleaseWarning;

  /// Current config (empty defaults before [install]).
  static MoleConfig get config => _config;

  /// Live entry store. `null` when inactive.
  static MoleStore? get store => _store;

  /// One-line install.
  ///
  /// Pass the storage instances you already created. Mole wraps them - it
  /// never creates or owns storage instances itself, and only the sources you
  /// list here appear in the inspector. Edits in Mole write through to those
  /// same instances immediately.
  ///
  /// Pass [onStorageChanged] so your app UI reloads when Mole mutates storage:
  ///
  /// ```dart
  /// Mole.install(
  ///   config: moleConfig,
  ///   sources: [MoleSharedPrefsSource(prefs)],
  ///   onStorageChanged: () => reloadMyUiFromStorage(),
  /// );
  /// ```
  static void install({
    MoleConfig config = const MoleConfig(),
    List<MoleSource> sources = const [],
    VoidCallback? onStorageChanged,
  }) {
    _config = config;
    _activation = MoleActivation.resolve(config);

    if (!_activation.active) {
      _tearDown();
      _installed = true;
      return;
    }

    _store ??= MoleStore(debounce: config.refreshDebounce);
    _store!.onStorageChanged = onStorageChanged;
    _engine ??= MoleEngine(store: _store!, config: config);
    _engine!.updateConfig(config);
    _engine!.attach(sources);

    if (_activation.showReleaseWarning) {
      printMoleReleaseWarning();
    }

    _installed = true;
  }

  /// Registers additional sources after [install].
  ///
  /// No-op when Mole is inactive.
  static void addSources(Iterable<MoleSource> sources) {
    if (!_activation.active) return;
    _engine?.attach(sources);
  }

  /// Inserts the floating bubble overlay.
  ///
  /// Prefer [builder] on your [MaterialApp] so this happens automatically.
  static void showOverlay(BuildContext context) {
    if (!_activation.active || _store == null || _engine == null) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    hideOverlay();
    _overlayEntry = OverlayEntry(builder: (context) => _bubble());
    overlay.insert(_overlayEntry!);
  }

  /// Removes the floating bubble if present.
  static void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Opens the dashboard as a full-screen route.
  ///
  /// Prefer attaching [navigatorKey] to your [MaterialApp] so this works from
  /// [builder].
  static Future<void> openDashboard([BuildContext? context]) async {
    if (!_activation.active || _store == null) return;
    if (_inspectorOpen.value) return;

    final nav =
        navigatorKey.currentState ??
        (context != null
            ? Navigator.maybeOf(context, rootNavigator: true)
            : null);

    if (nav == null) {
      debugPrint(
        'Mole: no Navigator found. '
        'Set MaterialApp(navigatorKey: Mole.navigatorKey, builder: Mole.builder).',
      );
      return;
    }

    _inspectorOpen.value = true;
    try {
      // Re-read non-notifying sources (prefs/secure/cache) so data written by
      // the app while the dashboard was closed always shows up.
      await _store!.rescan();
      await nav.push(
        PageRouteBuilder<void>(
          opaque: true,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 120),
          reverseTransitionDuration: const Duration(milliseconds: 100),
          pageBuilder: (context, animation, secondaryAnimation) {
            return MoleDashboard(
              store: _store!,
              config: _config,
              onClearAll: (_store != null && _store!.isEmpty)
                  ? null
                  : () {
                      debugPrint('Mole cleared all sources');
                    },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      _inspectorOpen.value = false;
    }
  }

  static Widget _bubble() {
    return ListenableBuilder(
      listenable: _inspectorOpen,
      builder: (context, _) {
        if (_inspectorOpen.value) {
          return const SizedBox.shrink();
        }
        return MoleBubble(
          store: _store!,
          config: _config,
          showReleaseTag: _activation.showReleaseWarning,
          onOpen: () {
            unawaited(openDashboard());
          },
        );
      },
    );
  }

  /// Attach Mole to [MaterialApp.builder].
  ///
  /// Also set [navigatorKey] on your app so the floating button can open
  /// the inspector:
  ///
  /// ```dart
  /// MaterialApp(
  ///   navigatorKey: Mole.navigatorKey,
  ///   builder: Mole.builder,
  ///   home: HomePage(),
  /// )
  /// ```
  static Widget builder(BuildContext context, Widget? child) {
    if (!_activation.active || _store == null) {
      return child ?? const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      children: [child ?? const SizedBox.shrink(), _bubble()],
    );
  }

  /// Fully tear down Mole (tests / hot restart helpers).
  @visibleForTesting
  static void resetForTest() {
    _tearDown();
    _installed = false;
    _activation = const MoleActivation(
      active: false,
      showReleaseWarning: false,
    );
    _config = const MoleConfig();
  }

  static void _tearDown() {
    hideOverlay();
    _inspectorOpen.value = false;
    MoleBubble.clearPersistedPositionForTest();
    MoleBubble.clearUserHiddenForTest();
    _engine?.detachAll();
    _engine = null;
    _store?.dispose();
    _store = null;
  }

  /// Whether [install] has been called in this isolate.
  static bool get isInstalled => _installed;
}
