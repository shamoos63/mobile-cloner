import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n.dart';
import '../../../services/app_installer.dart';
import '../../../services/format.dart';
import '../../theme.dart';

/// "Install apps" after a transfer: Install all, or one at a time, with
/// each app's state. [beforeInstall] returns false when HK Cloner may not
/// install apps yet (it then sends the user to Android's setting).
class AppInstallList extends StatelessWidget {
  const AppInstallList({super.key, required this.queue, required this.beforeInstall});

  final AppInstallQueue queue;
  final Future<bool> Function() beforeInstall;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final s = S.of(context);
        final t = Theme.of(context).textTheme;
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        final waiting = queue.items.where((i) => i.state == AppInstallState.waiting).length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.installAppsHint, style: t.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: waiting == 0 || queue.running
                    ? null
                    : () async {
                        if (await beforeInstall()) await queue.installAll();
                      },
                icon: const Icon(Icons.install_mobile_rounded),
                label: Text('${s.installAll} (${ltr('$waiting')})'),
              ),
              const SizedBox(height: 4),
              for (final item in queue.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: item.bundle.iconPath == null
                        ? const Icon(Icons.android_rounded, size: 32)
                        : Image.file(File(item.bundle.iconPath!), width: 40, height: 40),
                  ),
                  title: Text(item.bundle.manifest.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_status(s, item), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _color(item.state, muted))),
                  trailing: switch (item.state) {
                    AppInstallState.installing => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    AppInstallState.installed => const Icon(Icons.check_circle_rounded, color: AppColors.teal),
                    _ when item.installable => TextButton(
                      onPressed: queue.running
                          ? null
                          : () async {
                              if (await beforeInstall()) await queue.installOne(item);
                            },
                      child: Text(s.install),
                    ),
                    _ => null,
                  },
                ),
            ]),
          ),
        );
      },
    );
  }

  static String _status(S s, AppInstallItem item) {
    final m = item.bundle.manifest;
    final info = '${ltr(m.versionName)} · ${formatBytes(m.sizeBytes)}';
    return switch (item.state) {
      AppInstallState.waiting => info,
      AppInstallState.installing => s.appStatusInstalling,
      AppInstallState.installed => s.appStatusInstalled,
      AppInstallState.alreadyInstalled => s.appStatusAlreadyInstalled,
      AppInstallState.canceled => s.appStatusCanceled,
      AppInstallState.failed => s.appStatusFailed(item.detail ?? s.unknownError),
      AppInstallState.needsNewerAndroid => s.appStatusNeedsAndroid(m.minSdk ?? 0),
      AppInstallState.incomplete => s.appStatusIncomplete,
    };
  }

  static Color? _color(AppInstallState state, Color muted) => switch (state) {
    AppInstallState.failed || AppInstallState.needsNewerAndroid || AppInstallState.incomplete => AppColors.rose,
    AppInstallState.installed => AppColors.teal,
    _ => muted,
  };
}
