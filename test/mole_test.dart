import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole/mole.dart';
import 'package:mole/src/core/mole_value_coercion.dart';

import 'fakes.dart';

void main() {
  group('MoleDataEntry', () {
    test('matches by key and value', () {
      const entry = MoleDataEntry(
        key: 'theme',
        value: 'dark',
        sourceType: 'prefs',
      );
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
      final fake = FakeMoleSource(store: {'a': 1, 'b': 2});
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

    test(
      'enabled false turns off release even when enableInRelease is true',
      () {
        final off = MoleActivation.resolve(
          const MoleConfig(enabled: false, enableInRelease: true),
          isReleaseMode: true,
        );
        expect(off.active, isFalse);
        expect(off.showReleaseWarning, isFalse);
      },
    );

    test('release warning only when active in release', () {
      final on = MoleActivation.resolve(
        const MoleConfig(enableInRelease: true),
        isReleaseMode: true,
      );
      expect(on.active, isTrue);
      expect(on.showReleaseWarning, isTrue);

      final off = MoleActivation.resolve(
        const MoleConfig(enableInRelease: false),
        isReleaseMode: true,
      );
      expect(off.active, isFalse);
      expect(off.showReleaseWarning, isFalse);
    });
  });

  group('MoleStore.onStorageChanged', () {
    test('fires immediately after setValue and deleteValue', () async {
      var changes = 0;
      final fake = FakeMoleSource();
      final store = MoleStore(onStorageChanged: () => changes++);
      store.addSource(fake);
      await _settle();

      await store.setValue(fake, 'a', '1');
      expect(changes, 1);

      await store.deleteValue(fake, 'a');
      expect(changes, 2);
    });
  });

  group('coerceEditedValue', () {
    test('preserves bool, int, and double types from text', () {
      expect(coerceEditedValue('false', true), isFalse);
      expect(coerceEditedValue('42', 7), 42);
      expect(coerceEditedValue('3.5', 1.0), 3.5);
    });

    test('parses JSON maps and lists', () {
      expect(coerceEditedValue('{"name":"mole"}', {'name': 'old'}), {
        'name': 'mole',
      });
      expect(coerceEditedValue('[1,2]', [0]), [1, 2]);
    });
  });

  testWidgets('dashboard lists only sources registered by the host app', (
    tester,
  ) async {
    final prefs = FakeMoleSource(name: 'SharedPreferences', type: 'prefs');
    final hive = FakeMoleSource(
      name: 'Hive Box',
      type: 'hive',
      store: {'k': 'v'},
    );
    final store = MoleStore();
    store.addSource(hive);

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

    expect(find.text('Hive Box'), findsOneWidget);
    expect(find.text('SharedPreferences'), findsNothing);
    expect(prefs, isNot(store.sources));
  });

  testWidgets('dashboard renders registered sources with counts', (
    tester,
  ) async {
    final fake = FakeMoleSource(store: {'k1': 'v1', 'k2': 'v2'});
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
