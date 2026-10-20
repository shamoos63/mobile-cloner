import '../migration/content_category.dart';
import '../migration/safe_path.dart';

/// Cloner-only metadata attached to a file (`cloner` field of a LocalSend
/// file DTO). Stock LocalSend ignores it and just saves `fileName`.
class ClonerFileMeta {
  const ClonerFileMeta({
    required this.category,
    required this.relPath,
    this.takenAt,
    this.mediaAlbum,
  });

  final ContentCategory category;

  /// Logical path inside the category, always forward slashes, never
  /// absolute. For WhatsApp it is relative to the WhatsApp root folder
  /// (e.g. `Databases/msgstore.db.crypt14`), so each side maps it to its own
  /// storage layout.
  final String relPath;

  /// When a photo or video was captured, kept so galleries sort correctly.
  final DateTime? takenAt;

  /// Source album / bucket, e.g. `Camera` or `Screenshots`.
  final String? mediaAlbum;

  factory ClonerFileMeta.fromJson(Map<String, Object?> json) => ClonerFileMeta(
    category: ContentCategory.parse(json['category']),
    relPath: SafePath.normalize(json['relPath'] as String? ?? ''),
    takenAt: DateTime.tryParse(json['takenAt'] as String? ?? ''),
    mediaAlbum: json['album'] as String?,
  );

  Map<String, Object?> toJson() => {
    'category': category.wireName,
    'relPath': relPath,
    'takenAt': ?takenAt?.toUtc().toIso8601String(),
    'album': ?mediaAlbum,
  };
}

class FileDto {
  const FileDto({
    required this.id,
    required this.fileName,
    required this.size,
    required this.fileType,
    this.sha256,
    this.preview,
    this.modified,
    this.accessed,
    this.cloner,
  });

  final String id;

  /// LocalSend file name. May contain `/` separated folders.
  final String fileName;
  final int size;
  final String fileType;
  final String? sha256;
  final String? preview;
  final DateTime? modified;
  final DateTime? accessed;
  final ClonerFileMeta? cloner;

  ContentCategory get category => cloner?.category ?? ContentCategory.files;

  /// Path inside the category, falling back to the LocalSend file name.
  String get relPath => cloner?.relPath ?? SafePath.normalize(fileName);

  factory FileDto.fromJson(Map<String, Object?> json) {
    final metadata = (json['metadata'] as Map?)?.cast<String, Object?>();
    return FileDto(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      size: (json['size'] as num).toInt(),
      fileType: json['fileType'] as String? ?? 'application/octet-stream',
      sha256: json['sha256'] as String?,
      preview: json['preview'] as String?,
      modified: DateTime.tryParse(metadata?['modified'] as String? ?? ''),
      accessed: DateTime.tryParse(metadata?['accessed'] as String? ?? ''),
      cloner: json['cloner'] is Map
          ? ClonerFileMeta.fromJson((json['cloner'] as Map).cast())
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'size': size,
    'fileType': fileType,
    'sha256': sha256,
    'preview': preview,
    if (modified != null || accessed != null)
      'metadata': {
        'modified': ?modified?.toUtc().toIso8601String(),
        'accessed': ?accessed?.toUtc().toIso8601String(),
      },
    'cloner': ?cloner?.toJson(),
  };
}
