import 'package:flutter/material.dart';

import '../config/mole_config.dart';
import '../core/mole_store.dart';
import 'mole_theme.dart';

/// Floating draggable bubble. Tap opens the Mole dashboard.
///
/// Follows the §3b spec - **no persistent count**. Storage writes are
/// occasional, not a stream, so a number would be meaningless noise:
///
/// - **Default state**: a database/cylinder icon (always solid).
/// - **Warning badge**: a small red dot appears **only if** total cache size
///   crosses [MoleConfig.cacheSizeWarningThresholdMB].
///
/// Drag uses pan-only gestures (no competing tap) and snaps to the nearer
/// horizontal edge on release — same model as Sway's floating button.
class MoleBubble extends StatefulWidget {
  /// Creates the floating Mole bubble overlay.
  const MoleBubble({
    super.key,
    required this.store,
    required this.config,
    required this.showReleaseTag,
    required this.onOpen,
  });

  /// Live store used for the cache-size warning dot.
  final MoleStore store;

  /// Bubble behavior thresholds (cache warning, etc.).
  final MoleConfig config;
  final bool showReleaseTag;

  /// Called when the user taps the bubble to open the inspector.
  final VoidCallback onOpen;

  @override
  State<MoleBubble> createState() => _MoleBubbleState();
}

class _MoleBubbleState extends State<MoleBubble> {
  static const _size = 48.0;
  static const _radius = 12.0;
  static const _edgeMargin = 8.0;
  static const _dragTapSlop = 8.0;

  /// How far from vertical-center toward the bottom safe edge (0 = center,
  /// 1 = bottom). Lands in the lower-middle band.
  static const _defaultLowerBand = 0.35;

  Offset? _offset;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  bool get _cacheOverThreshold {
    final thresholdBytes =
        widget.config.cacheSizeWarningThresholdMB * 1024 * 1024;
    return widget.store.totalCacheBytes >= thresholdBytes;
  }

  Offset _defaultOffset(Size size) {
    final center = (size.height - _size) / 2;
    final bottom = size.height - _size - 24;
    return Offset(
      size.width - _size - 16,
      center + (bottom - center) * _defaultLowerBand,
    );
  }

  Offset _clamp(Offset offset, MediaQueryData media) => Offset(
        offset.dx.clamp(_edgeMargin, media.size.width - _size - _edgeMargin),
        offset.dy.clamp(
          media.padding.top + _edgeMargin,
          media.size.height - _size - 24,
        ),
      );

  Offset _snapToEdge(Offset offset, MediaQueryData media) {
    final midX = media.size.width / 2;
    final snapLeft = offset.dx + _size / 2 < midX;
    final x = snapLeft
        ? _edgeMargin
        : media.size.width - _size - _edgeMargin;
    return _clamp(Offset(x, offset.dy), media);
  }

  void _onPanStart(DragStartDetails details) {
    _dragDistance = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final media = MediaQuery.of(context);
    final current = _offset ?? _defaultOffset(media.size);
    _dragDistance += details.delta.distance;
    setState(() => _offset = current + details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!mounted) return;
    if (_dragDistance < _dragTapSlop) {
      widget.onOpen();
      return;
    }
    final media = MediaQuery.of(context);
    final current = _offset ?? _defaultOffset(media.size);
    setState(() => _offset = _snapToEdge(current, media));
  }

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
    final position = _clamp(
      _offset ?? _defaultOffset(media.size),
      media,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
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
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
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
                      Icon(
                        Icons.storage_rounded,
                        size: 26,
                        color: foreground,
                      ),
                      if (_cacheOverThreshold) _warningDot(scheme),
                    ],
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
