import 'dart:async';
import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/cloner_service.dart';
import '../../services/format.dart';
import '../widgets/labels.dart';
import '../../version.dart';
import 'views/desktop_view.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  final service = ClonerService.instance;
  final adb = AdbBridge(adbPath: AdbBridge.locate(besides: _bundleDir()));
  PairingCode? _pairing;
  List<String> _addresses = [];
  List<(String, BackupManifest)> _backups = [];
  List<AdbDevice> _adbDevices = [];
  final Set<String> _linked = {};

  /// Per-phone setup state shown on the USB row.
  final Map<String, String> _adbStatus = {};
  final Set<String> _adbBusy = {};

  /// Phones already set up while plugged in; unplugging clears them.
  final Set<String> _handled = {};
  Timer? _adbPoll;
  String _folder = '';
  DesktopSection _section = DesktopSection.overview;

  @override
  void initState() {
    super.initState();
    _refresh();
    service.addListener(_onService);
    _adbPoll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshAdb());
  }

  @override
  void dispose() {
    _adbPoll?.cancel();
    service.removeListener(_onService);
    super.dispose();
  }

  ReceiveSession? _seenSession;
  void _onService() {
    // Reload the backup list when a backup finishes.
    if (service.lastBackupSession != _seenSession) {
      _seenSession = service.lastBackupSession;
      _loadBackups();
    }
  }

  Future<void> _refresh() async {
    final code = await service.pairingCode();
    _folder = await service.backupRoot();
    setState(() {
      _pairing = code;
      _addresses = code.addresses;
    });
    await _loadBackups();
    await _refreshAdb();
    _offerResume();
  }

  Future<void> _loadBackups() async {
    final list = await BackupStore(await service.backupRoot()).listBackups();
    if (mounted) setState(() => _backups = list);
  }

  Future<void> _refreshAdb() async {
    List<AdbDevice> list;
    try {
      list = await adb.list();
    } catch (_) {
      list = []; // adb missing: the row explains how to connect instead.
    }
    if (!mounted) return;
    final present = {for (final d in list) d.serial};
    _handled.removeWhere((s) => !present.contains(s));
    _linked.removeWhere((s) => !present.contains(s));
    _adbStatus.removeWhere((s, _) => !present.contains(s));
    for (final d in list) {
      if (d.unauthorized) _adbStatus[d.serial] = 'Tap "Allow" on the phone to trust this computer';
    }
    setState(() => _adbDevices = list);
    for (final d in list) {
      if (d.ready && !_handled.contains(d.serial)) {
        _handled.add(d.serial);
        unawaited(_link(d.serial));
      }
    }
  }

  /// Plugged in: install HK Cloner if it's missing or older, open it,
  /// and map the ports so it links to this computer by itself.
  Future<void> _link(String serial) async {
    setState(() {
      _adbBusy.add(serial);
      _adbStatus[serial] = 'Checking for HK Cloner...';
    });
    try {
      final apk = _bundledApk();
      final installed = await adb.installedVersion(serial, androidPackage);
      if (installed == null || installed < appVersionCode) {
        if (apk != null && mounted) {
          setState(() => _adbStatus[serial] = installed == null ? 'Installing HK Cloner...' : 'Updating HK Cloner...');
        }
      }
      final r = await adb.ensureAppRunning(
        serial,
        package: androidPackage,
        activity: androidActivity,
        versionCode: appVersionCode,
        apkPath: apk,
      );
      if (!mounted) return;
      setState(() {
        if (r.ok) _linked.add(serial);
        _adbStatus[serial] = switch (r) {
          AppSetupResult.installed => 'Installed and opened. Choose what to back up on the phone.',
          AppSetupResult.updated => 'Updated and opened. Choose what to back up on the phone.',
          AppSetupResult.alreadyInstalled => 'Opened on the phone. Choose what to back up there.',
          AppSetupResult.outdatedNoApk => 'Opened (older version on the phone).',
          AppSetupResult.missingApk => 'HK Cloner is not on the phone. Install the APK, then Retry.',
        };
      });
    } catch (e) {
      if (mounted) setState(() => _adbStatus[serial] = 'Setup failed: ${_short(e)}');
    } finally {
      if (mounted) setState(() => _adbBusy.remove(serial));
    }
  }

  static String _short(Object e) {
    final text = '$e'.replaceFirst('AdbException: ', '').trim();
    return text.length > 90 ? '${text.substring(0, 90)}...' : text;
  }

  /// Folder holding files shipped with the desktop app (APK, adb).
  static String _bundleDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    // macOS: Foo.app/Contents/MacOS/Foo -> Foo.app/Contents/Resources
    return Platform.isMacOS ? p.normalize(p.join(exeDir, '..', 'Resources')) : exeDir;
  }

  /// The phone APK shipped with this desktop build (CI copies it in), or
  /// MOBILE_CLONER_APK for development.
  static String? _bundledApk() {
    final candidates = [
      Platform.environment['MOBILE_CLONER_APK'],
      p.join(_bundleDir(), 'mobile-cloner.apk'),
      p.join(_bundleDir(), 'data', 'mobile-cloner.apk'),
    ];
    for (final c in candidates) {
      if (c != null && File(c).existsSync()) return c;
    }
    return null;
  }

  Future<void> _changeFolder() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Where should backups go?');
    if (dir == null) return;
    await service.setBackupRoot(dir);
    setState(() => _folder = dir);
    await _loadBackups();
  }

  Future<void> _restore(String dir) async {
    final targets = [
      ...service.peers.values.where((d) => d.info.cloner?.platform == ClonerPlatform.android),
    ];
    final choice = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Restore to which phone?'),
        children: [
          for (final d in targets)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text('${d.info.alias}  ·  ${d.ip}')),
          for (final s in _linked)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, s), child: Text('USB: ${_nameOf(s)}')),
          if (targets.isEmpty && _linked.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Open HK Cloner on the phone and tap "Restore from computer", or link it by USB.'),
            ),
        ],
      ),
    );
    if (choice == null) return;
    try {
      final target = choice is Device
          ? choice
          : await service.connectManual('127.0.0.1', port: AdbBridge.pcToPhonePort);
      final files = await BackupStore.filesToRestore(dir);
      await service.send(target, files, options: {'backupDir': dir});
      _afterRestore();
    } catch (e) {
      _snack('$e');
    }
  }

  void _afterRestore() {
    if (service.sendState == SendState.done) {
      _snack('Restore complete.');
    } else {
      _offerResume();
    }
  }

  /// An interrupted restore (also from before an app restart) gets a
  /// banner: the checkpoint records the backup folder and the phone.
  void _offerResume() {
    final cp = service.checkpoint;
    final dir = cp?.options['backupDir'];
    if (!mounted || cp == null || dir is! String) return;
    final m = ScaffoldMessenger.of(context)..clearMaterialBanners();
    m.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.pause_circle_outline_rounded),
        content: Text('Restore to ${cp.peerAlias} stopped at ${cp.doneFiles} of ${cp.totalFiles} files. '
            '${service.interruptText(cp.interruptReason)}'),
        actions: [
          TextButton(onPressed: () => _resumeRestore(dir), child: const Text('Resume')),
          TextButton(
            onPressed: () {
              m.clearMaterialBanners();
              service.discardCheckpoint();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  /// Same phone, any connection: Wi-Fi if it is visible, else the USB link.
  Future<void> _resumeRestore(String dir) async {
    final cp = service.checkpoint!;
    ScaffoldMessenger.of(context).clearMaterialBanners();
    try {
      final target = service.peers[cp.peerFingerprint] ??
          await service.connectManual('127.0.0.1', port: AdbBridge.pcToPhonePort);
      await service.resume(target: target, files: await BackupStore.filesToRestore(dir));
      _afterRestore();
    } catch (e) {
      _snack('Could not reach ${cp.peerAlias}: $e');
      _offerResume();
    }
  }

  String _nameOf(String serial) =>
      _adbDevices.where((d) => d.serial == serial).map((d) => d.model).firstOrNull ?? serial;

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  BackupCardData _card((String, BackupManifest) b) {
    final m = b.$2;
    final bytes = <ContentCategory, int>{};
    for (final e in m.categories.entries) {
      final v = e.value;
      if (v is Map && v['bytes'] is num) bytes[ContentCategory.parse(e.key)] = (v['bytes'] as num).toInt();
    }
    final when = m.lastBackup.toLocal();
    return BackupCardData(
      alias: m.alias,
      subtitle: [if (m.sdkInt != null) 'Android API ${m.sdkInt}', if (m.deviceModel != null) m.deviceModel!].join(' · '),
      lastBackup: _stamp(when),
      bytesByCategory: bytes,
      path: b.$1,
    );
  }

  /// One row per category per backup, newest first.
  List<HistoryEntry> _history() {
    final rows = <(DateTime, HistoryEntry)>[];
    for (final (_, m) in _backups) {
      for (final e in m.categories.entries) {
        final v = e.value;
        if (v is! Map) continue;
        final at = (DateTime.tryParse('${v['at']}') ?? m.lastBackup).toLocal();
        final files = (v['files'] as num?)?.toInt() ?? 0;
        final bytes = (v['bytes'] as num?)?.toInt() ?? 0;
        rows.add((
          at,
          HistoryEntry(
            title: '${categoryLabel(ContentCategory.parse(e.key))} from ${m.alias}',
            detail: '$files files · ${formatBytes(bytes)}',
            when: _stamp(at),
          ),
        ));
      }
    }
    rows.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final r in rows) r.$2];
  }

  static String _stamp(DateTime when) =>
      '${when.year}-${_two(when.month)}-${_two(when.day)} ${_two(when.hour)}:${_two(when.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final s = service.receiveSession;
        final live = s != null && s.state == SessionState.active
            ? LiveTransferData(
                peer: s.sender.info.alias,
                fraction: s.totalBytes == 0 ? 0 : s.receivedBytes / s.totalBytes,
                bytesPerSecond: service.receiveMeter.bytesPerSecond,
                doneBytes: s.receivedBytes,
                totalBytes: s.totalBytes,
                doneFiles: s.files.values.where((f) => f.state == FileState.done).length,
                totalFiles: s.files.length,
                eta: service.receiveMeter.eta(s.totalBytes - s.receivedBytes),
                peerStatus: service.senderStatus,
              )
            : null;
        return DesktopHomeView(
          hostName: service.self.alias,
          addresses: _addresses,
          pairing: _pairing,
          backupFolder: _folder,
          backups: [for (final b in _backups) _card(b)],
          adbDevices: [
            for (final d in _adbDevices)
              AdbDeviceData(
                serial: d.serial,
                name: d.model,
                connected: _linked.contains(d.serial),
                status: _adbStatus[d.serial],
                busy: _adbBusy.contains(d.serial),
              ),
          ],
          section: _section,
          nearby: [
            for (final d in service.peers.values) NearbyDeviceData(name: d.info.alias, address: d.ip),
          ],
          history: _history(),
          appVersion: '$appVersionName ($appVersionCode)',
          live: live,
          onSection: (s) => setState(() => _section = s),
          onChangeFolder: _changeFolder,
          onAdbConnect: _link,
          onAdbRefresh: _refreshAdb,
          onRestore: (b) => _restore(b.path!),
          onOpenFolder: (b) => _openFolder(b.path!),
          onPreview: (b) => _preview(b.path!),
          onDelete: (b) => _delete(b),
        );
      },
    );
  }

  Future<void> _delete(BackupCardData b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text('Delete the backup of ${b.alias}?'),
        content: Text('This removes ${formatBytes(b.totalBytes)} from\n${b.path}\n\nThe phone itself is not touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupStore(await service.backupRoot()).deleteBackup(b.path!);
      _snack('Deleted the backup of ${b.alias}.');
    } catch (e) {
      _snack('Could not delete: ${_short(e)}');
    }
    await _loadBackups();
  }

  /// Manifest summary per category, plus a few photo thumbnails.
  Future<void> _preview(String dir) async {
    final m = _backups.where((b) => b.$1 == dir).map((b) => b.$2).firstOrNull;
    if (m == null) return;
    final thumbs = <File>[];
    final photos = Directory(p.join(dir, ContentCategory.photos.wireName));
    if (await photos.exists()) {
      await for (final e in photos.list(recursive: true, followLinks: false)) {
        if (e is File && RegExp(r'\.(jpe?g|png|webp|gif|heic)$', caseSensitive: false).hasMatch(e.path)) {
          thumbs.add(e);
          if (thumbs.length == 8) break;
        }
      }
    }
    if (!mounted) return;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return AlertDialog(
          title: Text(m.alias),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    [
                      if (m.deviceModel != null) m.deviceModel!,
                      if (m.sdkInt != null) 'Android API ${m.sdkInt}',
                      'Last backup ${_stamp(m.lastBackup.toLocal())}',
                    ].join(' · '),
                    style: t.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 12),
                  for (final e in m.categories.entries)
                    if (e.value is Map)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(categoryIcon(ContentCategory.parse(e.key))),
                        title: Text(categoryLabel(ContentCategory.parse(e.key))),
                        subtitle: Text([
                          '${((e.value as Map)['files'] as num?)?.toInt() ?? 0} files',
                          formatBytes(((e.value as Map)['bytes'] as num?) ?? 0),
                          if (DateTime.tryParse('${(e.value as Map)['at']}') case final at?) _stamp(at.toLocal()),
                        ].join(' · ')),
                      ),
                  if (thumbs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Photos', style: t.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in thumbs)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            f,
                            width: 116,
                            height: 116,
                            fit: BoxFit.cover,
                            cacheWidth: 232,
                            errorBuilder: (_, _, _) => Container(
                              width: 116,
                              height: 116,
                              color: muted.withValues(alpha: 0.12),
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Future<void> _openFolder(String path) async {
    final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    await Process.run(cmd, [p.normalize(path)]);
  }
}

