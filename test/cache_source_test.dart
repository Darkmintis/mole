import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mole/mole.dart';

void main() {
  group('MoleCacheSource', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mole_cache_test');
    });

    tearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    test('lists files written into the cache directory', () async {
      await File('${temp.path}/a.json').writeAsString('{}');
      await File('${temp.path}/b.txt').writeAsString('hello');

      final source = MoleCacheSource(directoryPath: temp.path);
      final entries = await source.watch().first;
      final keys = entries.map((e) => e.key).toSet();

      expect(entries, hasLength(2));
      expect(keys, containsAll(<String>['a.json', 'b.txt']));
      // Cache entries carry a file descriptor, not a key/value.
      expect(entries.first.value, isA<MoleFileEntry>());
      expect(entries.first.sourceType, 'cache');
      expect(entries.first.isSensitive, isFalse);
    });

    test('deletes a single file', () async {
      final f = File('${temp.path}/target.txt');
      await f.writeAsString('bye');

      final source = MoleCacheSource(directoryPath: temp.path);
      await source.deleteValue('target.txt');

      expect(await f.exists(), isFalse);
      expect(await source.watch().first, isEmpty);
    });

    test('clearAll removes every file but keeps the directory', () async {
      await File('${temp.path}/one.txt').writeAsString('1');
      await File('${temp.path}/two.txt').writeAsString('2');

      final source = MoleCacheSource(directoryPath: temp.path);
      await source.clearAll();

      expect(await temp.list().toList(), isEmpty);
      expect(await temp.exists(), isTrue);
    });

    test('setValue is unsupported (files are view/delete only)', () {
      final source = MoleCacheSource(directoryPath: temp.path);
      expect(
        () => source.setValue('k', 'v'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('MoleValueRenderer.canEdit', () {
    test('rejects raw bytes and cache files', () {
      expect(
        MoleValueRenderer.canEdit(
          MoleDataEntry(key: 'b', value: Uint8List(0), sourceType: 'hive'),
        ),
        isFalse,
      );
      expect(
        MoleValueRenderer.canEdit(
          const MoleDataEntry(key: 'f', value: MoleFileEntry(name: 'x', path: '/x', size: 0, modified: null, mimeType: '', isImage: false), sourceType: 'cache'),
        ),
        isFalse,
      );
    });

    test('allows primitives and JSON-safe maps/lists', () {
      expect(
        MoleValueRenderer.canEdit(
          const MoleDataEntry(key: 's', value: 'hello', sourceType: 'prefs'),
        ),
        isTrue,
      );
      expect(
        MoleValueRenderer.canEdit(
          const MoleDataEntry(key: 'm', value: <String, dynamic>{'a': 1}, sourceType: 'hive'),
        ),
        isTrue,
      );
    });
  });

  group('MoleValueRenderer (widget)', () {
    testWidgets('renders a primitive value', (tester) async {
      const entry = MoleDataEntry(key: 'theme', value: 'dark', sourceType: 'prefs');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MoleValueRenderer(entry: entry)),
        ),
      );
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('renders a masked secure value', (tester) async {
      const entry = MoleDataEntry(
        key: 'token',
        value: 'secret',
        sourceType: 'secure',
        isSensitive: true,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MoleValueRenderer(entry: entry, revealed: false)),
        ),
      );
      expect(find.text('••••••••'), findsOneWidget);
    });

    testWidgets('renders masked until revealed', (tester) async {
      const entry = MoleDataEntry(
        key: 'token',
        value: 'secret',
        sourceType: 'secure',
        isSensitive: true,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MoleValueRenderer(entry: entry, revealed: true)),
        ),
      );
      expect(find.text('secret'), findsOneWidget);
    });
  });
}
