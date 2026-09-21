import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole/mole.dart';

import 'fakes.dart';

/// Mirrors [MoleBubble]'s default lower-middle band (0.35 from center→bottom).
const _bubbleLowerBand = 0.35;

void main() {
  group('MoleConfig.cacheSizeWarningThresholdMB', () {
    test('defaults to 50', () {
      expect(const MoleConfig().cacheSizeWarningThresholdMB, 50);
    });

    test('is carried through copyWith', () {
      const base = MoleConfig(cacheSizeWarningThresholdMB: 20);
      expect(base.copyWith().cacheSizeWarningThresholdMB, 20);
      expect(
        base
            .copyWith(cacheSizeWarningThresholdMB: 80)
            .cacheSizeWarningThresholdMB,
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
      final fake = FakeMoleSource(store: {'s': 'hello', 'i': 42, 'b': true});
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

      // Host app writes straight to storage - no stream emit, so the store
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
      final fake = FakeMoleSource(store: {'a': 1, 'b': 2, 'c': 3});
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

    testWidgets('defaults to lower-middle on the right edge', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpWithBubble(tester, const MoleConfig());

      const size = 48.0;
      const center = (800 - size) / 2;
      const bottom = 800 - size - 24;
      const expectedTop = center + (bottom - center) * _bubbleLowerBand;

      final bubble = tester.getRect(find.byType(MoleBubble));
      expect(bubble.right, closeTo(400 - 16, 0.1));
      expect(bubble.top, closeTo(expectedTop, 0.1));
    });

    testWidgets('does not show the warning dot under the threshold', (
      tester,
    ) async {
      await pumpWithBubble(
        tester,
        const MoleConfig(cacheSizeWarningThresholdMB: 100),
      );
      expect(
        find.byKey(const ValueKey('mole-cache-warning-dot')),
        findsNothing,
      );
    });

    testWidgets('shows the warning dot when cache bytes cross the threshold', (
      tester,
    ) async {
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

    testWidgets('tiny pan opens inspector (tap via slop)', (tester) async {
      var opened = false;
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
                config: const MoleConfig(),
                showReleaseTag: false,
                onOpen: () => opened = true,
              ),
            ],
          ),
        ),
      );

      await tester.timedDrag(
        find.byIcon(Icons.storage_rounded),
        const Offset(2, 0),
        const Duration(milliseconds: 50),
      );
      expect(opened, isTrue);
    });

    testWidgets('drag snaps to nearer horizontal edge', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpWithBubble(tester, const MoleConfig());

      final button = find.byIcon(Icons.storage_rounded);
      final before = tester.getCenter(button);
      await tester.drag(button, const Offset(-200, -80));
      await tester.pumpAndSettle();

      final after = tester.getCenter(button);
      expect(after.dx, lessThan(before.dx - 50));
      expect(after.dx, closeTo(8 + 24, 1)); // edgeMargin + half size
    });

    testWidgets('remembers position after bubble is remounted', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(MoleBubble.clearPersistedPositionForTest);

      final fake = FakeMoleSource();
      final store = MoleStore();
      store.addSource(fake);
      await tester.pump(const Duration(milliseconds: 300));

      Widget bubble() => MaterialApp(
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
      );

      await tester.pumpWidget(bubble());
      final button = find.byIcon(Icons.storage_rounded);
      await tester.drag(button, const Offset(-200, -80));
      await tester.pumpAndSettle();
      final saved = tester.getCenter(button);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(bubble());
      await tester.pumpAndSettle();

      final restored = tester.getCenter(find.byIcon(Icons.storage_rounded));
      expect(restored.dx, closeTo(saved.dx, 1));
      expect(restored.dy, closeTo(saved.dy, 1));
    });

    testWidgets('long-press hides the bubble until reassemble', (tester) async {
      addTearDown(MoleBubble.clearUserHiddenForTest);
      addTearDown(MoleBubble.clearPersistedPositionForTest);

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
                config: const MoleConfig(),
                showReleaseTag: false,
                onOpen: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);

      final button = find.byIcon(Icons.storage_rounded);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.storage_rounded), findsNothing);

      unawaited(tester.binding.reassembleApplication());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    });
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
}
