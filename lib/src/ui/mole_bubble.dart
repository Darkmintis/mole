import 'dart:async';

import 'package:flutter/material.dart';

import '../config/mole_config.dart';
import '../core/mole_store.dart';
import 'mole_theme.dart';

/// ponytail: process-local only (survives inspector open/close + hot reload).
/// Upgrade: shared_preferences if QA needs cross-process restore.
Offset? _persistedBubblePosition;

/// ponytail: process-local hide (survives hot reload until [reassemble] / restart).
bool _userHidden = false;

const _kLongPressHide = Duration(milliseconds: 450);

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
/// Long-press hides until hot reload / hot restart.
/// Position is remembered for the process so closing the inspector does not
/// reset the bubble.
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

  /// Draws the red release-build border around the bubble.
  final bool showReleaseTag;

  /// Called when the user taps the bubble to open the inspector.
  final VoidCallback onOpen;

  /// Clears remembered bubble position (tests / [Mole.resetForTest]).
  static void clearPersistedPositionForTest() {
    _persistedBubblePosition = null;
  }

  /// Clears long-press hide (tests / [Mole.resetForTest]).
  static void clearUserHiddenForTest() {
    _userHidden = false;
  }

  @override
  State<MoleBubble> createState() => _MoleBubbleState();
}

class _MoleBubbleState extends State<MoleBubble> {
  static const _size = 48.0;
  static const _radius = 12.0;
  static const _edgeMargin = 12.0;
  static const _dragTapSlop = 8.0;

  /// How far from vertical-center toward the bottom safe edge (0 = center,
  /// 1 = bottom). Lands in the lower-middle band.
  static const _defaultLowerBand = 0.35;

  /// Current offset (top-left). Restored from [_persistedBubblePosition] when
  /// set; otherwise lower-middle on the right edge.
  Offset? _offset;
  double _dragDistance = 0;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _offset = _persistedBubblePosition;
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_userHidden) {
      _userHidden = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
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

  /// Top-left bounds: [_edgeMargin] from every edge, inside the safe area
  /// (status bar, navigation bar, notches) — same rule as Ferret and Sway.
  Rect _bounds(MediaQueryData media) {
    final pad = media.padding;
    return Rect.fromLTRB(
      pad.left + _edgeMargin,
      pad.top + _edgeMargin,
      media.size.width - pad.right - _size - _edgeMargin,
      media.size.height - pad.bottom - _size - _edgeMargin,
    );
  }

  Offset _defaultOffset(MediaQueryData media) {
    final b = _bounds(media);
    final center = (b.top + b.bottom) / 2;
    return Offset(b.right, center + (b.bottom - center) * _defaultLowerBand);
  }

  Offset _clamp(Offset offset, MediaQueryData media) {
    final b = _bounds(media);
    return Offset(
      offset.dx.clamp(b.left, b.right),
      offset.dy.clamp(b.top, b.bottom),
    );
  }

  Offset _snapToEdge(Offset offset, MediaQueryData media) {
    final b = _bounds(media);
    final snapLeft = offset.dx + _size / 2 < media.size.width / 2;
    return _clamp(Offset(snapLeft ? b.left : b.right, offset.dy), media);
  }

  void _persistPosition() {
    if (_offset != null) {
      _persistedBubblePosition = _offset;
    }
  }

  void _hideBubble() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _userHidden = true;
    if (mounted) setState(() {});
  }

  void _onPanStart(DragStartDetails details) {
    _dragDistance = 0;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(_kLongPressHide, () {
      if (_dragDistance < _dragTapSlop && mounted && !_userHidden) {
        _hideBubble();
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final media = MediaQuery.of(context);
    final current = _offset ?? _defaultOffset(media);
    _dragDistance += details.delta.distance;
    if (_dragDistance >= _dragTapSlop) {
      _longPressTimer?.cancel();
      _longPressTimer = null;
    }
    setState(() => _offset = current + details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (!mounted || _userHidden) return;
    if (_dragDistance < _dragTapSlop) {
      widget.onOpen();
      return;
    }
    final media = MediaQuery.of(context);
    final current = _offset ?? _defaultOffset(media);
    setState(() {
      _offset = _snapToEdge(current, media);
      _persistPosition();
    });
  }

  /// Small red dot pinned to the top-right corner - shown only when total
  /// cache size crosses the §3b threshold.
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
    if (_userHidden) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    // The first frame can report a 0×0 screen; clamp bounds would be invalid.
    if (media.size.isEmpty) return const SizedBox.shrink();
    final position = _clamp(_offset ?? _defaultOffset(media), media);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: MoleTheme.wrap(context, (context) {
        final scheme = Theme.of(context).colorScheme;
        final background = scheme.inverseSurface;
        final foreground = scheme.onInverseSurface;

        final button = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Material(
            color: background,
            elevation: 3,
            shadowColor: Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
              side: widget.showReleaseTag
                  ? const BorderSide(color: Color(0xFFB3261E), width: 3)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.storage_rounded, size: 26, color: foreground),
                  if (_cacheOverThreshold) _warningDot(scheme),
                ],
              ),
            ),
          ),
        );
        if (!widget.showReleaseTag) return button;
        return Semantics(label: 'Mole active in release build', child: button);
      }),
    );
  }
}
