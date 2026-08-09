import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole/mole.dart';

import 'fakes.dart';

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
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
}