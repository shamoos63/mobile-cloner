import '../migration/content_category.dart';

class CategoryStats {
  CategoryStats({this.files = 0, this.bytes = 0, this.failed = 0});

  int files;
  int bytes;
  int failed;

  factory CategoryStats.fromJson(Map<String, Object?> json) => CategoryStats(
    files: (json['files'] as num?)?.toInt() ?? 0,
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    failed: (json['failed'] as num?)?.toInt() ?? 0,
  );

  Map<String, Object?> toJson() => {'files': files, 'bytes': bytes, 'failed': failed};
}

/// What a sender reports at the end of a session (Cloner extension).
class SessionSummary {
  SessionSummary({Map<ContentCategory, CategoryStats>? categories, this.sourceSdkInt})
    : categories = categories ?? {};

  final Map<ContentCategory, CategoryStats> categories;
  final int? sourceSdkInt;

  CategoryStats of(ContentCategory c) => categories.putIfAbsent(c, CategoryStats.new);

  factory SessionSummary.fromJson(Map<String, Object?> json) => SessionSummary(
    sourceSdkInt: (json['sourceSdkInt'] as num?)?.toInt(),
    categories: {
      for (final e in ((json['categories'] as Map?) ?? const {}).entries)
        ContentCategory.parse(e.key): CategoryStats.fromJson((e.value as Map).cast()),
    },
  );

  Map<String, Object?> toJson() => {
    'sourceSdkInt': ?sourceSdkInt,
    'categories': {for (final e in categories.entries) e.key.wireName: e.value.toJson()},
  };
}
