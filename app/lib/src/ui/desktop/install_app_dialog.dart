import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n.dart';
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
    final s = S.of(context);
    final title = widget.app.missing ? s.appMissingOn(widget.deviceName) : s.appOutdatedOn(widget.deviceName);
    return AlertDialog(
      icon: const Icon(Icons.install_mobile_rounded),
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          ..._body(s, t, muted),
        ]),
      ),
      actions: _actions(context, s),
    );
  }

  List<Widget> _body(S s, TextTheme t, Color muted) {
    switch (_phase) {
      case _Phase.installing:
        return [
          Text(s.installingOn(widget.deviceName), style: t.bodyMedium),
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(s.installTapInstall, style: t.bodySmall?.copyWith(color: muted)),
        ];
      case _Phase.failed:
        return [Text(_failureText(s, _failure!), style: t.bodyMedium)];
      case _Phase.ready:
        if (_apk == null) {
          return [
            Text(s.noBundledApk(ltr(PhoneApk.fileName)), style: t.bodyMedium),
          ];
        }
        return [
          Text(
            widget.app.missing
                ? s.installExplain
                : s.updateExplain(ltr('${widget.app.installedVersion}')),
            style: t.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.android_rounded, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _chosen ? '${ltr(p.basename(_apk!))} · $_size' : s.apkSummary(ltr(widget.bundledVersion), _size),
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ];
    }
  }

  String _failureText(S s, AdbInstallException e) => switch (e.failure) {
    InstallFailure.updateIncompatible => s.installUpdateIncompatible,
    InstallFailure.downgrade => s.installDowngrade,
    InstallFailure.blocked => s.installBlocked,
    InstallFailure.notAuthorized => s.installNotAuthorized,
    InstallFailure.noSpace => s.installNoSpace(_size),
    InstallFailure.invalidApk => s.installInvalidApk,
    InstallFailure.other => s.installFailed(e.detail),
  };

  List<Widget> _actions(BuildContext context, S s) {
    final cancel = TextButton(onPressed: () => Navigator.pop(context), child: Text(s.notNow));
    final choose = TextButton(onPressed: _choose, child: Text(s.chooseApk));
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
              child: Text(s.uninstallAndInstall),
            ),
          ];
        }
        return [
          cancel,
          choose,
          if (f != InstallFailure.invalidApk) FilledButton(onPressed: _install, child: Text(s.tryAgain)),
        ];
      case _Phase.ready:
        if (_apk == null) return [cancel, FilledButton(onPressed: _choose, child: Text(s.chooseApk))];
        return [
          cancel,
          choose,
          FilledButton(
            onPressed: _install,
            child: Text(widget.app.missing ? s.installOnPhone : s.updateOnPhone),
          ),
        ];
    }
  }
}
