import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole/mole.dart';

import 'fakes.dart';

void main() {
  group('MoleDataEntry', () {
    test('matches by key and value', () {
      const entry = MoleDataEntry(key: 'theme', value: 'dark', sourceType: 'prefs');
      expect(entry.matches('theme'), isTrue);
      expect(entry.matches('DARK'), isTrue);
      expect(entry.matches('nope'), isFalse);
      expect(entry.matches(''), isTrue);
    });

    test('masks preview for sensitive entries', () {
      const secret = MoleDataEntry(
        key: 'token',
        value: 'abc',
        sourceType: 'secure',
        isSensitive: true,
      );
      expect(secret.toString(), contains('***'));
    });
  });

  group('MoleStore', () {
    test('registers sources and caches snapshots', () async {
      final fake = FakeMoleSource(
        store: {
          'a': 1,
          'b': 2,
        },
      );
      final store = MoleStore();
      store.addSource(fake);

      expect(store.sources, contains(fake));
      await _settle();
      expect(store.totalEntries, 2);

      fake.push([
        const MoleDataEntry(key: 'a', value: 1),
        const MoleDataEntry(key: 'b', value: 2),
        const MoleDataEntry(key: 'c', value: 3),
      ]);
      await _settle();
      expect(store.countOf(fake), 3);

      store.removeSource(fake);
      expect(store.sources, isEmpty);
    });

    test('set / delete / clear call through to the source', () async {
      final fake = FakeMoleSource();
      final store = MoleStore();
      store.addSource(fake);
      await _settle();

      await store.setValue(fake, 'a', '1');
      expect(fake.values['a'], '1');

      await store.deleteValue(fake, 'a');
      expect(fake.values.containsKey('a'), isFalse);

      await store.clearAll();
      expect(fake.values, isEmpty);
    });
  });

  group('MoleActivation', () {
    test('debug respects enabled flag', () {
      expect(
        MoleActivation.resolve(
          const MoleConfig(enabled: true),
          isReleaseMode: false,
        ).active,
        isTrue,
      );
      expect(
        MoleActivation.resolve(
          const MoleConfig(enabled: false),
          isReleaseMode: false,
        ).active,
        isFalse,
      );
    });

    test('release is off unless enableInRelease', () {
      final off = MoleActivation.resolve(
        const MoleConfig(),
        isReleaseMode: true,
      );
      expect(off.active, isFalse);
      expect(off.showReleaseWarning, isFalse);

      final on = MoleActivation.resolve(
        const MoleConfig(enableInRelease: true),
        isReleaseMode: true,
      );
      expect(on.active, isTrue);
      expect(on.showReleaseWarning, isTrue);
    });

    test('release warning cannot be disabled when active in release', () {
      final on = MoleActivation.resolve(
        const MoleConfig(enableInRelease: true),
        isReleaseMode: true,
      );
      expect(on.active, isTrue);
      expect(on.showReleaseWarning, isTrue);
    });
  });

  testWidgets('dashboard renders registered sources with counts', (tester) async {
    final fake = FakeMoleSource(
      store: {
        'k1': 'v1',
        'k2': 'v2',
      },
    );
    final store = MoleStore();
    store.addSource(fake);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(
      MaterialApp(
        home: MoleDashboard(
          store: store,
          config: const MoleConfig(),
          onClearAll: () {},
        ),
      ),
    );

    expect(find.text('Mole'), findsOneWidget);
    expect(find.text('Fake Source'), findsOneWidget);
    expect(find.text('2 entries · 2'), findsOneWidget);
  });
}

Future<void> _settle() async {
  // Allow debounce timers and stream events to flush.
  await Future<void>.delayed(const Duration(milliseconds: 250));
}