import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('backups'));
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> backup(String name) async {
    final dir = Directory(p.join(root.path, name));
    await File(p.join(dir.path, 'photos', 'a.jpg')).create(recursive: true);
    await File(p.join(dir.path, BackupStore.manifestName)).writeAsString('{"alias":"$name","lastBackup":"2026-01-01T00:00:00Z"}');
    return dir.path;
  }

  test('deleteBackup removes that backup only', () async {
    final store = BackupStore(root.path);
    final a = await backup('A');
    await backup('B');
    await store.deleteBackup(a);
    expect(Directory(a).existsSync(), isFalse);
    expect((await store.listBackups()).map((b) => b.$2.alias), ['B']);
  });

  test('deleteBackup refuses folders that are not backups', () async {
    final store = BackupStore(root.path);
    final plain = Directory(p.join(root.path, 'plain'))..createSync();
    await expectLater(store.deleteBackup(plain.path), throwsArgumentError);
    await expectLater(store.deleteBackup(root.path), throwsArgumentError);
    final a = await backup('A');
    await expectLater(store.deleteBackup(p.join(a, 'photos')), throwsArgumentError);
    expect(plain.existsSync(), isTrue);
  });
}
