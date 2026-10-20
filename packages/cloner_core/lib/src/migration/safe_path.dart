import 'package:path/path.dart' as p;

/// Paths arrive from the network, so every one is normalized and checked
/// before it touches the file system: no absolute paths, no `..`, no drive
/// letters, no empty segments.
abstract final class SafePath {
  static String normalize(String raw) {
    final unified = raw.replaceAll('\\', '/');
    final segments = <String>[];
    for (final segment in unified.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        throw UnsafePathException(raw);
      }
      if (segment.contains(':') || segment.contains('\u0000')) {
        throw UnsafePathException(raw);
      }
      segments.add(segment);
    }
    return segments.join('/');
  }

  /// Joins [relPath] under [root] (native separators) and verifies the result
  /// stays inside [root].
  static String resolveUnder(String root, String relPath) {
    final normalized = normalize(relPath);
    if (normalized.isEmpty) throw UnsafePathException(relPath);
    final joined = p.normalize(p.joinAll([root, ...normalized.split('/')]));
    if (!p.isWithin(p.normalize(root), joined)) {
      throw UnsafePathException(relPath);
    }
    return joined;
  }
}

class UnsafePathException implements Exception {
  UnsafePathException(this.path);
  final String path;
  @override
  String toString() => 'UnsafePathException: "$path"';
}
