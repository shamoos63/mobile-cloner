import 'dart:convert';
import 'dart:io';

/// Remembers which files from each sender were already restored, so a
/// resumed or repeated transfer doesn't duplicate photos in the gallery or
/// contacts in the address book.
class ReceiveJournal {
  ReceiveJournal(this.path);

  final String path;
  Map<String, Set<String>> _done = {};
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final json = jsonDecode(await File(path).readAsString()) as Map;
      _done = json.map((k, v) => MapEntry(k as String, {for (final id in v as List) id as String}));
    } catch (_) {}
  }

  Future<Set<String>> doneFor(String fingerprint) async {
    await _load();
    return _done[fingerprint] ?? const {};
  }

  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  /// Records a restored file. Flushes at most every 2 seconds so a phone
  /// that dies mid-transfer loses at most a couple of entries.
  Future<void> markDone(String fingerprint, String fileId) async {
    await _load();
    (_done[fingerprint] ??= {}).add(fileId);
    if (DateTime.now().difference(_lastFlush) > const Duration(seconds: 2)) await flush();
  }

  Future<void> flush() async {
    _lastFlush = DateTime.now();
    final tmp = File('$path.tmp');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(jsonEncode(_done.map((k, v) => MapEntry(k, v.toList()))), flush: true);
    await tmp.rename(path);
  }
}
