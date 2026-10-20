import 'dart:convert';
import 'dart:io';

import '../migration/content_category.dart';

/// Why a transfer stopped before finishing.
enum InterruptReason {
  connectionLost,
  lowBatterySelf,
  lowBatteryPeer,
  paused,
  appKilled,
  error,
}

/// Durable record of a transfer in progress: which peer, what was selected,
/// which files are done and how far the current ones got. Written after
/// every file and every few megabytes with an atomic rename, so a phone
/// that dies mid-transfer leaves a valid file to resume from.
class TransferCheckpoint {
  TransferCheckpoint({
    required this.transferId,
    required this.peerFingerprint,
    required this.peerAlias,
    required this.role,
    required this.categories,
    required this.totalFiles,
    required this.totalBytes,
    Set<String>? doneFileIds,
    Map<String, int>? partialBytes,
    this.lastAddress,
    this.lastPort,
    this.connectionMode,
    this.interruptReason,
    this.options = const {},
    DateTime? startedAt,
    DateTime? updatedAt,
  }) : doneFileIds = doneFileIds ?? {},
       partialBytes = partialBytes ?? {},
       startedAt = startedAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String transferId;
  final String peerFingerprint;
  final String peerAlias;

  /// `send` or `receive`.
  final String role;
  final Set<ContentCategory> categories;
  final int totalFiles;
  final int totalBytes;
  final Set<String> doneFileIds;
  final Map<String, int> partialBytes;
  String? lastAddress;
  int? lastPort;
  String? connectionMode;
  InterruptReason? interruptReason;

  /// Selection details needed to rebuild the file list (e.g. WhatsApp scope).
  final Map<String, Object?> options;
  final DateTime startedAt;
  DateTime updatedAt;

  int get doneFiles => doneFileIds.length;

  factory TransferCheckpoint.fromJson(Map<String, Object?> json) => TransferCheckpoint(
    transferId: json['transferId'] as String,
    peerFingerprint: json['peerFingerprint'] as String,
    peerAlias: json['peerAlias'] as String? ?? '',
    role: json['role'] as String? ?? 'send',
    categories: {for (final c in (json['categories'] as List? ?? const [])) ContentCategory.parse(c)},
    totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
    totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
    doneFileIds: {for (final id in (json['done'] as List? ?? const [])) id as String},
    partialBytes: ((json['partial'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
    lastAddress: json['lastAddress'] as String?,
    lastPort: (json['lastPort'] as num?)?.toInt(),
    connectionMode: json['connectionMode'] as String?,
    interruptReason: InterruptReason.values.asNameMap()[json['interruptReason']],
    options: ((json['options'] as Map?) ?? const {}).cast(),
    startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );

  Map<String, Object?> toJson() => {
    'formatVersion': 1,
    'transferId': transferId,
    'peerFingerprint': peerFingerprint,
    'peerAlias': peerAlias,
    'role': role,
    'categories': [for (final c in categories) c.wireName],
    'totalFiles': totalFiles,
    'totalBytes': totalBytes,
    'done': doneFileIds.toList(),
    'partial': partialBytes,
    'lastAddress': lastAddress,
    'lastPort': lastPort,
    'connectionMode': connectionMode,
    'interruptReason': interruptReason?.name,
    'options': options,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// Stores the checkpoint as JSON with write-to-temp + rename, which is
/// atomic on Android, Linux, macOS and NTFS.
class CheckpointStore {
  CheckpointStore(this.path);

  final String path;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  Future<TransferCheckpoint?> load() async {
    final f = File(path);
    if (!await f.exists()) return null;
    try {
      return TransferCheckpoint.fromJson((jsonDecode(await f.readAsString()) as Map).cast());
    } catch (_) {
      return null;
    }
  }

  /// Saves now, or at most once per [minInterval] unless [force].
  Future<void> save(TransferCheckpoint cp, {bool force = false, Duration minInterval = const Duration(seconds: 2)}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastWrite) < minInterval) return;
    _lastWrite = now;
    cp.updatedAt = now;
    final tmp = File('$path.tmp');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(jsonEncode(cp.toJson()), flush: true);
    await tmp.rename(path);
  }

  Future<void> clear() async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
