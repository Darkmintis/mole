import 'package:flutter/material.dart';

import '../config/mole_config.dart';
import '../core/mole_store.dart';
import 'mole_theme.dart';

/// Floating draggable bubble. Tap opens the Mole dashboard.
///
/// Follows the §3b spec — **no persistent count**. Storage writes are
/// occasional, not a stream, so a number would be meaningless noise:
///
/// - **Default state**: a database/cylinder icon.
/// - **Pulse-on-write**: brief ~500ms opacity/scale glow whenever any
///   registered source changes. No number — just a visual pulse.
/// - **Warning badge**: a small red dot appears **only if** total cache size
///   crosses [MoleConfig.cacheSizeWarningThresholdMB].
///
/// The pulse runs on the [AnimationController] it owns locally; it never
/// rebuilds the dashboard or source views, keeping §6 near-zero overhead.
class MoleBubble extends StatefulWidget {
  const MoleBubble({
    super.key,
    required this.store,
    required this.config,
    required this.showReleaseTag,
    required this.onOpen,
  });

  final MoleStore store;
  final MoleConfig config;
  final bool showReleaseTag;
  final VoidCallback onOpen;

  @override
  State<MoleBubble> createState() => _MoleBubbleState();
}

class _MoleBubbleState extends State<MoleBubble>
    with SingleTickerProviderStateMixin {
  static const _size = 52.0;
  static const _radius = 14.0;
  static const _pulseDuration = Duration(milliseconds: 500);

  /// How far above the *exact* bottom-right corner the bubble sits by default
  /// — clear of a typical floating action button (~56px + 16px gap).
  static const _cornerMargin = 80.0;

  /// Current offset (top-left). `null` until the user drags — while null the
  /// bubble sits a little above the bottom-right corner (§3b default).
  Offset? _offset;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.35,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  late final Animation<double> _scale = Tween<double>(
    begin: 0.9,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOutCubic));

  /// Writes are occasional, so a pulse only replays on real changes (not on
  /// the first listener registration, which fires the initial snapshot).
  bool _pulsedOnce = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    // Skip the initial snapshot so the bubble doesn't glow on first build.
    if (!_pulsedOnce) {
      _pulsedOnce = true;
      return;
    }
    _pulse.forward(from: 0);
  }

  bool get _cacheOverThreshold {
    final thresholdBytes = widget.config.cacheSizeWarningThresholdMB * 1024 * 1024;
    return widget.store.totalCacheBytes >= thresholdBytes;
  }

  /// Small red dot pinned to the top-right corner — shown only when total
  /// cache size crosses the §3b threshold. Added to the bubble's inner stack.
  Widget _warningDot(ColorScheme scheme) {
    return Positioned(
      key: const ValueKey('mole-cache-warning-dot'),
      top: 8,
      right: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFB3261E),
          shape: BoxShape.circle,
          border: Border.all(color: scheme.inverseSurface, width: 1.5),
        ),
        child: const SizedBox(width: 9, height: 9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Default position: bottom-right but a little above the exact corner, so
    // it doesn't overlap a floating action button / system gesture bar.
    final position = _offset ??
        Offset(
          media.size.width - _size - 16,
          media.size.height - _size - _cornerMargin,
        );

    return Positioned(
      left: position.dx.clamp(8.0, media.size.width - _size - 8),
      top: position.dy.clamp(
        media.padding.top + 8,
        media.size.height - _size - 24,
      ),
      child: MoleTheme.wrap(context, (context) {
        final scheme = Theme.of(context).colorScheme;
        final background = scheme.inverseSurface;
        final foreground = scheme.onInverseSurface;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.showReleaseTag)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: const Color(0xFFB3261E),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'MOLE ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final media = MediaQuery.of(context);
                final end =
                    (_offset ??
                        Offset(
                          media.size.width - _size - 16,
                          media.size.height - _size - _cornerMargin,
                        )) +
                    details.delta;
                setState(() => _offset = end);
              },
              onTap: widget.onOpen,
              child: ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _opacity,
                  child: Material(
                    color: background,
                    elevation: 3,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(_radius),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: _size,
                      height: _size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Database/cylinder icon — the §3b default state.
                          Icon(
                            Icons.storage_rounded,
                            size: 28,
                            color: foreground,
                          ),
                          if (_cacheOverThreshold) _warningDot(scheme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}