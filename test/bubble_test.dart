import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole/mole.dart';

import 'fakes.dart';

/// Mirrors [MoleBubble]'s default corner clearance (above the exact corner).
const _bubbleCornerMargin = 80.0;

void main() {
  group('MoleConfig.cacheSizeWarningThresholdMB', () {
    test('defaults to 50', () {
      expect(const MoleConfig().cacheSizeWarningThresholdMB, 50);
    });

    test('is carried through copyWith', () {
      const base = MoleConfig(cacheSizeWarningThresholdMB: 20);
      expect(base.copyWith().cacheSizeWarningThresholdMB, 20);
      expect(
        base.copyWith(cacheSizeWarningThresholdMB: 80).cacheSizeWarningThresholdMB,
        80,
      );
    });
  });

  group('MoleStore.totalCacheBytes', () {
    test('sums MoleFileEntry sizes across cache sources', () async {
      final cache = FakeMoleSource(
        store: {
          'a.png': const MoleFileEntry(
            name: 'a.png',
            path: '/a.png',
            size: 300,
            modified: null,
            mimeType: 'image/png',
            isImage: true,
          ),
        },
      );
      final store = MoleStore();
      store.addSource(cache);
      await _settle();

      expect(store.totalCacheBytes, 300);
    });

    test('ignores non-file entries (prefs strings, hive numbers)', () async {
      final fake = FakeMoleSource(
        store: {
          's': 'hello',
          'i': 42,
          'b': true,
        },
      );
      final store = MoleStore();
      store.addSource(fake);
      await _settle();

      expect(store.totalCacheBytes, 0);
    });
  });

  group('MoleStore.rescan', () {
    test('picks up external writes that never hit the source stream', () async {
      final fake = FakeMoleSource(store: {'existing': 'v1'});
      final store = MoleStore();
      store.addSource(fake);
      await _settle();

      expect(store.entriesOf(fake).length, 1);

      // Host app writes straight to storage — no stream emit, so the store
      // (and dashboard) still show the stale snapshot.
      fake.seed('more', 'v2');
      await _settle();
      expect(store.entriesOf(fake).length, 1);

      await store.rescan();
      await _settle();
      expect(store.entriesOf(fake).length, 2);
    });

    test('is reflected in totalEntries after external mutations', () async {
      final fake = FakeMoleSource();
      final store = MoleStore();
      store.addSource(fake);
      await _settle();

      fake.seed('a', 1);
      fake.seed('b', 2);
      await store.rescan();
      await _settle();

      expect(store.totalEntries, 2);
    });
  });

  group('MoleBubble (§3b)', () {
    Future<(MoleStore, FakeMoleSource)> pumpWithBubble(
      WidgetTester tester,
      MoleConfig config,
    ) async {
      final fake = FakeMoleSource();
      final store = MoleStore();
      store.addSource(fake);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              MoleBubble(
                store: store,
                config: config,
                showReleaseTag: false,
                onOpen: () {},
              ),
            ],
          ),
        ),
      );
      return (store, fake);
    }

    testWidgets('shows a database icon, never a count number', (tester) async {
      final fake = FakeMoleSource(
        store: {
          'a': 1,
          'b': 2,
          'c': 3,
        },
      );
      final store = MoleStore();
      store.addSource(fake);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              MoleBubble(
                store: store,
                config: const MoleConfig(),
                showReleaseTag: false,
                onOpen: () {},
              ),
            ],
          ),
        ),
      );

      // Database/cylinder icon, no persistent number.
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('defaults to the bottom-right, a bit above the corner', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpWithBubble(tester, const MoleConfig());

      final bubble = tester.getRect(find.byType(MoleBubble));
      // Bubble is 52x52 and its Positioned should sit ~16px off the right edge
      // and ~80px above the bottom (clear of a typical FAB).
      expect(bubble.right, closeTo(400 - 16, 0.1));
      expect(bubble.bottom, closeTo(800 - _bubbleCornerMargin, 0.1));
    });

    testWidgets('pulses (fires animation) when a source changes', (
      tester,
    ) async {
      final (store, fake) = await pumpWithBubble(tester, const MoleConfig());

      // Writes a new source change; the pulse controller animates opacity.
      fake.set('k', 'v');
      await tester.pump(const Duration(milliseconds: 100));

      final iconFinder = find.byIcon(Icons.storage_rounded);
      // During the pulse the opacity is < 1 somewhere in the 500ms window.
      final ancestorOpacity = tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: iconFinder,
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(ancestorOpacity, lessThan(1.0));

      // Drain the store's debounce timer so nothing is pending at teardown.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('does not show the warning dot under the threshold',
        (tester) async {
      await pumpWithBubble(
        tester,
        const MoleConfig(cacheSizeWarningThresholdMB: 100),
      );
      expect(
        find.byKey(const ValueKey('mole-cache-warning-dot')),
        findsNothing,
      );
    });

    testWidgets('shows the warning dot when cache bytes cross the threshold',
        (tester) async {
      final cache = FakeMoleSource(
        store: {
          'big.bin': const MoleFileEntry(
            name: 'big.bin',
            path: '/big.bin',
            size: 1024 * 1024 * 100,
            modified: null,
            mimeType: 'application/octet-stream',
            isImage: false,
          ),
        },
      );
      final store = MoleStore();
      store.addSource(cache);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              MoleBubble(
                store: store,
                config: const MoleConfig(cacheSizeWarningThresholdMB: 50),
                showReleaseTag: false,
                onOpen: () {},
              ),
            ],
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('mole-cache-warning-dot')),
        findsOneWidget,
      );
    });

    testWidgets('is dimmed when no registered source has data', (tester) async {
      await pumpWithBubble(tester, const MoleConfig());

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, closeTo(0.38, 0.01));
    });

    testWidgets('is full opacity when any source has data', (tester) async {
      final (store, fake) = await pumpWithBubble(tester, const MoleConfig());
      fake.set('key', 'value');
      await tester.pump(const Duration(milliseconds: 300));

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
      expect(store.totalEntries, 1);
    });
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
}