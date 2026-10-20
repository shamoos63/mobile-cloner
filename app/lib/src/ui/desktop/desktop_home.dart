import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/cloner_service.dart';
import 'views/desktop_view.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  final service = ClonerService.instance;
  final adb = AdbBridge();
  PairingCode? _pairing;
  List<String> _addresses = [];
  List<(String, BackupManifest)> _backups = [];
  List<String> _adbSerials = [];
  final Set<String> _linked = {};
  String _folder = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    service.addListener(_onService);
  }

  @override
  void dispose() {
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
    try {
      final serials = await adb.devices();
      if (mounted) setState(() => _adbSerials = serials);
    } catch (_) {
      if (mounted) setState(() => _adbSerials = []);
    }
  }

  Future<void> _link(String serial) async {
    try {
      await adb.connect(serial);
      setState(() => _linked.add(serial));
      _snack('Linked. On the phone choose "Back up to computer" > "Computer over USB".');
    } catch (e) {
      _snack('$e');
    }
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
            SimpleDialogOption(onPressed: () => Navigator.pop(context, s), child: Text('USB: $s')),
          if (targets.isEmpty && _linked.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Open Mobile Cloner on the phone and tap "Restore from computer", or link it by USB.'),
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
      lastBackup: '${when.year}-${_two(when.month)}-${_two(when.day)} ${_two(when.hour)}:${_two(when.minute)}',
      bytesByCategory: bytes,
      path: b.$1,
    );
  }

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
          adbDevices: [for (final serial in _adbSerials) AdbDeviceData(serial: serial, connected: _linked.contains(serial))],
          live: live,
          onChangeFolder: _changeFolder,
          onAdbConnect: _link,
          onAdbRefresh: _refreshAdb,
          onRestore: (b) => _restore(b.path!),
          onOpenFolder: (b) => _openFolder(b.path!),
        );
      },
    );
  }

  Future<void> _openFolder(String path) async {
    final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    await Process.run(cmd, [p.normalize(path)]);
  }
}

