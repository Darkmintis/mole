import 'package:flutter/material.dart';

import '../core/mole_store.dart';
import 'mole_theme.dart';

/// Simple floating count button. Tap opens the Mole dashboard.
///
/// Shows the total number of stored entries across all sources as a badge.
class MoleBubble extends StatefulWidget {
  const MoleBubble({
    super.key,
    required this.store,
    required this.showReleaseTag,
    required this.onOpen,
  });

  final MoleStore store;
  final bool showReleaseTag;
  final VoidCallback onOpen;

  @override
  State<MoleBubble> createState() => _MoleBubbleState();
}

class _MoleBubbleState extends State<MoleBubble> {
  static const _size = 52.0;
  static const _radius = 14.0;

  Offset _offset = const Offset(16, 120);

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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final count = widget.store.totalEntries;

    return Positioned(
      left: _offset.dx.clamp(8.0, media.size.width - _size - 8),
      top: _offset.dy.clamp(
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
            Material(
              color: background,
              elevation: 3,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(_radius),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: _size,
                height: _size,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() => _offset += details.delta);
                  },
                  onTap: widget.onOpen,
                  child: ColoredBox(
                    color: background,
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: count >= 100 ? 14 : 16,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
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