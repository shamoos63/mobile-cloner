import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/format.dart';

/// "HK Cloner isn't on (phone)": installs the bundled (or a chosen) APK over
/// USB. Pops `true` once the app is on the phone, null when the user backs
/// out. The adb calls come in as callbacks so tests can fake them.
class InstallAppDialog extends StatefulWidget {
  const InstallAppDialog({
    super.key,
    required this.deviceName,
    required this.app,
    required this.apkPath,
    required this.bundledVersion,
    required this.install,
    required this.uninstall,
    required this.pickApk,
  });

  final String deviceName;
  final PhoneApp app;

  /// The APK shipped with this desktop build; null when none was found.
  final String? apkPath;

  /// Version of the shipped APK, e.g. `0.1.0 (1)`.
  final String bundledVersion;

  final Future<void> Function(String apkPath) install;

  /// Removes the app and its data from the phone.
  final Future<void> Function() uninstall;
  final Future<String?> Function() pickApk;

  @override
  State<InstallAppDialog> createState() => _InstallAppDialogState();
}

enum _Phase { ready, installing, failed }

class _InstallAppDialogState extends State<InstallAppDialog> {
  late String? _apk = widget.apkPath;
  bool get _chosen => _apk != null && _apk != widget.apkPath;
  _Phase _phase = _Phase.ready;
  AdbInstallException? _failure;

  Future<void> _choose() async {
    final path = await widget.pickApk();
    if (path != null) {
      setState(() {
        _apk = path;
        _phase = _Phase.ready;
        _failure = null;
      });
    }
  }

  Future<void> _install({bool uninstallFirst = false}) async {
    setState(() {
      _phase = _Phase.installing;
      _failure = null;
    });
    try {
      if (uninstallFirst) await widget.uninstall();
      await widget.install(_apk!);
      if (mounted) Navigator.pop(context, true);
    } on AdbInstallException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _failure = e;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _failure = AdbInstallException(InstallFailure.other, '$e'.replaceFirst('AdbException: ', ''));
        });
      }
    }
  }

  String get _size => _apk == null ? '' : formatBytes(File(_apk!).lengthSync());

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final title = widget.app.missing
        ? "HK Cloner isn't on ${widget.deviceName}"
        : 'HK Cloner on ${widget.deviceName} is out of date';
    return AlertDialog(
      icon: const Icon(Icons.install_mobile_rounded),
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          ..._body(t, muted),
        ]),
      ),
      actions: _actions(context),
    );
  }

  List<Widget> _body(TextTheme t, Color muted) {
    switch (_phase) {
      case _Phase.installing:
        return [
          Text('Installing on ${widget.deviceName}. This takes up to a minute.', style: t.bodyMedium),
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text('If the phone asks whether to install, tap Install.', style: t.bodySmall?.copyWith(color: muted)),
        ];
      case _Phase.failed:
        return [Text(_failureText(_failure!), style: t.bodyMedium)];
      case _Phase.ready:
        if (_apk == null) {
          return [
            Text(
              'No phone app was found in this copy of HK Cloner. Choose the HK Cloner APK '
              '(${PhoneApk.fileName}) to install it on the phone.',
              style: t.bodyMedium,
            ),
          ];
        }
        return [
          Text(
            widget.app.missing
                ? 'This computer installs HK Cloner on the phone over the cable, then opens it.'
                : 'The phone has version ${widget.app.installedVersion}. Updating keeps its data.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.android_rounded, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _chosen ? '${p.basename(_apk!)} · $_size' : 'HK Cloner ${widget.bundledVersion} · $_size',
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ];
    }
  }

  String _failureText(AdbInstallException e) => switch (e.failure) {
    InstallFailure.updateIncompatible =>
      'A different copy of HK Cloner is on the phone (built on another computer or from another store). Android '
          'only replaces it after uninstalling it, which deletes HK Cloner\'s data on the phone: its settings and any '
          'unfinished transfer. Photos, contacts and other apps are not touched.',
    InstallFailure.downgrade =>
      'The phone has a newer HK Cloner than this one. Installing this version means uninstalling the newer one '
          'first, which deletes HK Cloner\'s data on the phone. Photos, contacts and other apps are not touched.',
    InstallFailure.blocked =>
      'The phone refused the install. Look at the phone: if it asks, tap Install (or "Install anyway"). On Xiaomi '
          'phones turn on Developer options > "Install via USB". Then try again.',
    InstallFailure.notAuthorized =>
      'The phone does not trust this computer yet. Unlock it and tap Allow on "Allow USB debugging?" '
          '(tick "Always allow from this computer"), then try again.',
    InstallFailure.noSpace => 'Not enough free space on the phone. Free up at least $_size and try again.',
    InstallFailure.invalidApk => "That file isn't a working HK Cloner APK. Choose another one.",
    InstallFailure.other => 'The install failed: ${e.detail}',
  };

  List<Widget> _actions(BuildContext context) {
    final cancel = TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now'));
    final choose = TextButton(onPressed: _choose, child: const Text('Choose APK...'));
    switch (_phase) {
      case _Phase.installing:
        return const [];
      case _Phase.failed:
        final f = _failure!.failure;
        if (f == InstallFailure.updateIncompatible || f == InstallFailure.downgrade) {
          return [
            cancel,
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => _install(uninstallFirst: true),
              child: const Text('Uninstall and install'),
            ),
          ];
        }
        return [
          cancel,
          choose,
          if (f != InstallFailure.invalidApk) FilledButton(onPressed: _install, child: const Text('Try again')),
        ];
      case _Phase.ready:
        if (_apk == null) return [cancel, FilledButton(onPressed: _choose, child: const Text('Choose APK...'))];
        return [
          cancel,
          choose,
          FilledButton(
            onPressed: _install,
            child: Text(widget.app.missing ? 'Install on phone' : 'Update on phone'),
          ),
        ];
    }
  }
}
