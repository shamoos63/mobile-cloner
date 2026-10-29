import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloner_core/cloner_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n.dart';
import '../../platform/android_bridge.dart';
import '../../services/app_settings.dart';
import '../../services/cloner_service.dart';
import '../../services/format.dart';
import '../widgets/labels.dart';
import '../../version.dart';
import '../phone/views/app_picker_view.dart';
import 'install_app_dialog.dart';
import 'title_bar.dart';
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
      if (d.unauthorized) _adbStatus[d.serial] = tr.adbTapAllow;
    }
    setState(() => _adbDevices = list);
    for (final d in list) {
      if (d.ready && !_handled.contains(d.serial)) {
        _handled.add(d.serial);
        unawaited(_link(d.serial));
      }
    }
  }

  /// An install prompt is open; other phones wait for Retry.
  bool _prompting = false;

  /// Plugged in: open HK Cloner linked to this computer. When it is missing
  /// or older, ask first and install the APK shipped with this build.
  Future<void> _link(String serial) async {
    setState(() {
      _adbBusy.add(serial);
      _adbStatus[serial] = tr.adbChecking;
    });
    try {
      final app = await adb.appState(serial, androidPackage, versionCode: appVersionCode);
      var status = tr.adbOpened;
      if (!app.ready) {
        final installed = await _promptInstall(serial, app);
        if (!mounted) return;
        if (installed) {
          status = app.missing
              ? tr.adbInstalledOpened
              : tr.adbUpdatedOpened;
        } else if (app.missing) {
          setState(() => _adbStatus[serial] = tr.adbMissingRetry);
          return;
        } else {
          status = tr.adbOlderOpened;
        }
      }
      await adb.openLinked(serial, package: androidPackage, activity: androidActivity);
      if (!mounted) return;
      setState(() {
        _linked.add(serial);
        _adbStatus[serial] = status;
      });
    } catch (e) {
      if (mounted) setState(() => _adbStatus[serial] = tr.adbSetupFailed(_short(e)));
    } finally {
      if (mounted) setState(() => _adbBusy.remove(serial));
    }
  }

  /// "HK Cloner isn't on (phone)" with Install on phone. True once installed.
  Future<bool> _promptInstall(String serial, PhoneApp app) async {
    if (_prompting || !mounted) return false;
    _prompting = true;
    setState(() => _adbStatus[serial] = app.missing ? tr.adbMissing : tr.adbOutdated);
    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InstallAppDialog(
          deviceName: _nameOf(serial),
          app: app,
          apkPath: PhoneApk.locate(_bundleDir()),
          bundledVersion: '$appVersionName ($appVersionCode)',
          install: (apk) => adb.install(serial, apk),
          uninstall: () => adb.uninstall(serial, androidPackage),
          pickApk: () async {
            final r = await FilePicker.pickFiles(
              dialogTitle: tr.chooseApkDialogTitle,
              type: FileType.custom,
              allowedExtensions: const ['apk'],
            );
            return r?.files.single.path;
          },
        ),
      );
      return ok == true;
    } finally {
      _prompting = false;
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

  Future<void> _changeFolder() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: tr.whereBackupsGo);
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
        title: Text(tr.restoreToWhichPhone),
        children: [
          for (final d in targets)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, d), child: Text('${d.info.alias}  ·  ${ltr(d.ip)}')),
          for (final s in _linked)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, s), child: Text(tr.usbDeviceName(_nameOf(s)))),
          if (targets.isEmpty && _linked.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr.restoreNoPhone),
            ),
        ],
      ),
    );
    if (choice == null) return;
    try {
      final target = choice is Device
          ? choice
          : await service.connectManual('127.0.0.1', port: AdbBridge.pcToPhonePort);
      // Over USB the computer installs the apps itself (adb); over Wi-Fi the
      // phone gets the APKs and shows its own "Install apps" list.
      final serial = choice is String ? choice : null;
      final files = await BackupStore.filesToRestore(
        dir,
        only: serial == null ? null : ({...ContentCategory.values}..remove(ContentCategory.apps)),
      );
      if (files.isNotEmpty) await service.send(target, files, options: {'backupDir': dir});
      if (serial != null) await _installApps(serial, dir);
      _afterRestore();
    } catch (e) {
      _snack('$e');
    }
  }

  /// Installs the backup's apps on a USB-linked phone, one by one, skipping
  /// those already there at the same or a newer version.
  Future<void> _installApps(String serial, String dir, {Set<String>? only}) async {
    final bundles = [
      for (final b in await AppBundle.scan(p.join(dir, ContentCategory.apps.wireName)))
        if (b.complete && (only == null || only.contains(b.packageName))) b,
    ];
    if (bundles.isEmpty || !mounted) return;
    final progress = ValueNotifier<(int, String)>((0, ''));
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.install_mobile_rounded),
        title: Text(tr.installApps),
        content: ValueListenableBuilder<(int, String)>(
          valueListenable: progress,
          builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.installingAppOf(v.$2, v.$1 + 1, bundles.length)),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: v.$1 / bundles.length),
          ]),
        ),
      ),
    ));
    var installed = 0;
    final failed = <String>[];
    for (final (i, b) in bundles.indexed) {
      progress.value = (i, b.manifest.label);
      try {
        final have = await adb.installedVersion(serial, b.packageName);
        if (have != null && have >= b.manifest.versionCode) {
          installed++;
          continue;
        }
        await adb.installApp(serial, b.apkPaths);
        installed++;
      } catch (e) {
        failed.add(b.manifest.label);
      }
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    _snack([
      tr.appsInstalledSummary(installed, bundles.length),
      if (failed.isNotEmpty) tr.appsNotInstalled(failed.join(', ')),
    ].join(' '));
  }

  void _afterRestore() {
    if (service.sendState == SendState.done) {
      _snack(tr.restoreComplete);
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
        content: Text('${tr.restoreStopped(cp.peerAlias, cp.doneFiles, cp.totalFiles)} '
            '${service.interruptText(cp.interruptReason)}'),
        actions: [
          TextButton(onPressed: () => _resumeRestore(dir), child: Text(tr.resume)),
          TextButton(
            onPressed: () {
              m.clearMaterialBanners();
              service.discardCheckpoint();
            },
            child: Text(tr.discard),
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
      _snack(tr.couldNotReach(cp.peerAlias, '$e'));
      _offerResume();
    }
  }

  String _nameOf(String serial) =>
      _adbDevices.where((d) => d.serial == serial).map((d) => d.model).firstOrNull ?? serial;

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // --- Apps over USB ---------------------------------------------------------

  static const _phoneApi = 'http://127.0.0.1:${AdbBridge.pcToPhonePort}';
  final Map<String, Uint8List?> _phoneIcons = {};

  /// The phone's third-party apps: from HK Cloner on the phone (names and
  /// icons) when it answers, else straight from adb (package names only).
  Future<(List<InstalledApp>, bool fromPhone)> _phoneApps(String serial) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final res = await (await client.getUrl(Uri.parse('$_phoneApi${ApiRoute.apps}'))).close().timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final list = jsonDecode(await res.transform(utf8.decoder).join()) as List;
        client.close();
        return ([for (final m in list) InstalledApp.fromMap(m as Map)], true);
      }
      client.close();
    } catch (e) {
      debugPrint('HKCloner.apps: phone app list unavailable, using adb: $e');
    }
    final apps = await adb.thirdPartyApps(serial, exclude: androidPackage);
    return (
      [
        for (final a in apps)
          InstalledApp(
            packageName: a.packageName,
            label: a.packageName,
            versionName: a.versionName,
            versionCode: a.versionCode,
            apks: a.apks,
            sizeBytes: a.sizeBytes,
            readable: true,
          ),
      ],
      false,
    );
  }

  Future<Uint8List?> _phoneIcon(String package) async {
    if (_phoneIcons.containsKey(package)) return _phoneIcons[package];
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final res = await (await client.getUrl(Uri.parse('$_phoneApi${ApiRoute.appIcon}?package=$package'))).close();
      final bytes = res.statusCode == 200 ? await res.fold<BytesBuilder>(BytesBuilder(), (b, c) => b..add(c)) : null;
      client.close();
      return _phoneIcons[package] = bytes?.takeBytes();
    } catch (_) {
      return _phoneIcons[package] = null;
    }
  }

  /// The app picker in a window of its own (title bar kept).
  Future<Set<String>?> _pickApps(List<InstalledApp> apps, Future<Uint8List?> Function(String) iconFor) =>
      Navigator.push<Set<String>>(
        context,
        MaterialPageRoute(
          builder: (route) => Column(children: [
            const DesktopTitleBar(),
            Expanded(
              child: AppPickerView(apps: apps, initial: const {}, iconFor: iconFor, onDone: (s) => Navigator.pop(route, s)),
            ),
          ]),
        ),
      );

  /// Shows [run]'s progress (index, label) over [total] items.
  Future<T> _withProgress<T>(String title, int total, Future<T> Function(ValueNotifier<(int, String)> progress) run,
      String Function(int index, String label) line) async {
    final progress = ValueNotifier<(int, String)>((0, ''));
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.apps_rounded),
        title: Text(title),
        content: ValueListenableBuilder<(int, String)>(
          valueListenable: progress,
          builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line(v.$1, v.$2)),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: total == 0 ? null : v.$1 / total),
          ]),
        ),
      ),
    ));
    try {
      return await run(progress);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
    }
  }

  /// Back up apps from a USB-linked phone: pick, then `adb pull` each APK
  /// into the phone's backup folder with app.json and the icon.
  Future<void> _backupAppsOverUsb(String serial) async {
    setState(() => _adbBusy.add(serial));
    List<InstalledApp> apps;
    bool fromPhone;
    DeviceInfo device;
    try {
      (apps, fromPhone) = await _phoneApps(serial);
      Device? phone;
      try {
        phone = await service.connectManual('127.0.0.1', port: AdbBridge.pcToPhonePort);
      } catch (_) {}
      final model = _nameOf(serial);
      device = phone?.info ?? DeviceInfo(alias: model, fingerprint: serial, deviceModel: model);
    } catch (e) {
      if (mounted) setState(() => _adbBusy.remove(serial));
      _snack(tr.adbSetupFailed(_short(e)));
      return;
    }
    if (!mounted) return;
    setState(() => _adbBusy.remove(serial));
    apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    final chosen = await _pickApps(apps, fromPhone ? _phoneIcon : (_) async => null);
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final picked = [for (final a in apps) if (chosen.contains(a.packageName)) a];
    final store = BackupStore(await service.backupRoot());
    final failed = <String>[];
    var files = 0, bytes = 0, copied = 0;
    await _withProgress(tr.backUpApps, picked.length, (progress) async {
      for (final (i, a) in picked.indexed) {
        progress.value = (i, a.label);
        final dir = p.join(store.deviceDir(device), ContentCategory.apps.wireName, a.packageName);
        try {
          await Directory(dir).create(recursive: true);
          final names = <String>[];
          for (final (j, remote) in a.apks.indexed) {
            final name = j == 0 ? AppManifest.baseApk : p.posix.basename(remote);
            await adb.pull(serial, remote, p.join(dir, name));
            names.add(name);
            bytes += await File(p.join(dir, name)).length();
            files++;
          }
          await File(p.join(dir, AppManifest.fileName)).writeAsString(jsonEncode(AppManifest(
            packageName: a.packageName,
            label: a.label,
            versionName: a.versionName,
            versionCode: a.versionCode,
            apks: names,
            sizeBytes: a.sizeBytes,
            minSdk: a.minSdk,
          ).toJson()));
          final icon = fromPhone ? await _phoneIcon(a.packageName) : null;
          if (icon != null) await File(p.join(dir, AppManifest.iconFileName)).writeAsBytes(icon);
          copied++;
        } catch (e) {
          debugPrint('HKCloner.apps: pulling ${a.packageName} failed: $e');
          failed.add(a.label);
        }
      }
    }, (i, label) => tr.copyingAppOf(label, i + 1, picked.length));
    if (copied > 0) await store.recordCategory(device, ContentCategory.apps, files: files, bytes: bytes);
    await _loadBackups();
    _snack([tr.appsBackedUp(copied), if (failed.isNotEmpty) tr.appsNotCopied(failed.join(', '))].join(' '));
  }

  /// "Restore apps" on a backup: pick some, install them on the USB phone.
  Future<void> _restoreApps(BackupCardData b) async {
    final dir = b.path!;
    final bundles = await AppBundle.scan(p.join(dir, ContentCategory.apps.wireName));
    if (bundles.isEmpty || !mounted) return;
    final serial = _linked.firstOrNull;
    if (serial == null) {
      _snack(tr.plugInForApps);
      return;
    }
    final icons = {for (final x in bundles) x.packageName: x.iconPath};
    final chosen = await _pickApps(
      [
        for (final x in bundles)
          InstalledApp(
            packageName: x.packageName,
            label: x.manifest.label,
            versionName: x.manifest.versionName,
            versionCode: x.manifest.versionCode,
            apks: x.apkPaths,
            sizeBytes: x.manifest.sizeBytes,
            readable: x.complete,
            minSdk: x.manifest.minSdk,
          ),
      ],
      (pkg) async => icons[pkg] == null ? null : File(icons[pkg]!).readAsBytes(),
    );
    if (chosen == null || chosen.isEmpty) return;
    await _installApps(serial, dir, only: chosen);
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
      subtitle: [if (m.sdkInt != null) tr.androidApi(m.sdkInt!), if (m.deviceModel != null) m.deviceModel!].join(' · '),
      lastBackup: _stamp(when),
      bytesByCategory: bytes,
      path: b.$1,
      appCount: _appCount(b.$1),
    );
  }

  static int _appCount(String dir) {
    final apps = Directory(p.join(dir, ContentCategory.apps.wireName));
    return apps.existsSync() ? apps.listSync().whereType<Directory>().length : 0;
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
            title: tr.categoryFromDevice(categoryLabel(ContentCategory.parse(e.key)), m.alias),
            detail: '${tr.filesCount(files)} · ${formatBytes(bytes)}',
            when: _stamp(at),
          ),
        ));
      }
    }
    rows.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final r in rows) r.$2];
  }

  static String _stamp(DateTime when) =>
      ltr('${when.year}-${_two(when.month)}-${_two(when.day)} ${_two(when.hour)}:${_two(when.minute)}');

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
        final view = DesktopHomeView(
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
          language: AppSettings.instance.language,
          onLanguage: AppSettings.instance.setLanguage,
          live: live,
          onSection: (s) => setState(() => _section = s),
          onChangeFolder: _changeFolder,
          onAdbConnect: _link,
          onAdbRefresh: _refreshAdb,
          onAdbBackupApps: _backupAppsOverUsb,
          onRestoreApps: _restoreApps,
          onRestore: (b) => _restore(b.path!),
          onOpenFolder: (b) => _openFolder(b.path!),
          onPreview: (b) => _preview(b.path!),
          onDelete: (b) => _delete(b),
        );
        return Column(children: [const DesktopTitleBar(), Expanded(child: view)]);
      },
    );
  }

  Future<void> _delete(BackupCardData b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(tr.deleteBackupTitle(b.alias)),
        content: Text(tr.deleteBackupBody(formatBytes(b.totalBytes), ltr(b.path!))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupStore(await service.backupRoot()).deleteBackup(b.path!);
      _snack(tr.deletedBackup(b.alias));
    } catch (e) {
      _snack(tr.couldNotDelete(_short(e)));
    }
    await _loadBackups();
  }

  /// Manifest summary per category, plus a few photo thumbnails.
  Future<void> _preview(String dir) async {
    final m = _backups.where((b) => b.$1 == dir).map((b) => b.$2).firstOrNull;
    if (m == null) return;
    final apps = await AppBundle.scan(p.join(dir, ContentCategory.apps.wireName));
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
                      if (m.sdkInt != null) tr.androidApi(m.sdkInt!),
                      tr.lastBackupAt(_stamp(m.lastBackup.toLocal())),
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
                          tr.filesCount(((e.value as Map)['files'] as num?)?.toInt() ?? 0),
                          formatBytes(((e.value as Map)['bytes'] as num?) ?? 0),
                          if (DateTime.tryParse('${(e.value as Map)['at']}') case final at?) _stamp(at.toLocal()),
                        ].join(' · ')),
                      ),
                  if (apps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(tr.categoryApps, style: t.titleSmall),
                    for (final a in apps)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: a.iconPath == null
                            ? const Icon(Icons.android_rounded)
                            : Image.file(File(a.iconPath!), width: 32, height: 32),
                        title: Text(a.manifest.label),
                        subtitle: Text('${ltr(a.manifest.versionName)} · ${formatBytes(a.manifest.sizeBytes)}'),
                      ),
                  ],
                  if (thumbs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(tr.categoryPhotos, style: t.titleSmall),
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
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.close)),
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

