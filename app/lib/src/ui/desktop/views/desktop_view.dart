import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../services/format.dart';
import '../../theme.dart';
import '../../widgets/labels.dart';
import '../../widgets/visuals.dart';

class BackupCardData {
  const BackupCardData({
    required this.alias,
    required this.subtitle,
    required this.lastBackup,
    required this.bytesByCategory,
    this.path,
  });

  final String alias;
  final String subtitle;
  final String lastBackup;
  final Map<ContentCategory, int> bytesByCategory;
  final String? path;

  int get totalBytes => bytesByCategory.values.fold(0, (a, b) => a + b);
}

class LiveTransferData {
  const LiveTransferData({
    required this.peer,
    required this.fraction,
    required this.bytesPerSecond,
    required this.doneBytes,
    required this.totalBytes,
    required this.doneFiles,
    required this.totalFiles,
    this.eta,
    this.peerStatus,
    this.currentFile,
  });

  final String peer;
  final double fraction;
  final double bytesPerSecond;
  final int doneBytes;
  final int totalBytes;
  final int doneFiles;
  final int totalFiles;
  final Duration? eta;
  final PeerStatus? peerStatus;
  final String? currentFile;
}

class AdbDeviceData {
  const AdbDeviceData({required this.serial, required this.connected, this.name, this.status, this.busy = false});
  final String serial;
  final bool connected;

  /// Model name when adb reports it.
  final String? name;

  /// What the automatic setup is doing or needs ("Installing Mobile Cloner").
  final String? status;
  final bool busy;
}

/// Desktop backup station.
class DesktopHomeView extends StatelessWidget {
  const DesktopHomeView({
    super.key,
    required this.hostName,
    required this.addresses,
    required this.pairing,
    required this.backupFolder,
    required this.backups,
    required this.adbDevices,
    this.live,
    this.onChangeFolder,
    this.onAdbConnect,
    this.onAdbRefresh,
    this.onRestore,
    this.onOpenFolder,
  });

  final String hostName;
  final List<String> addresses;
  final PairingCode? pairing;
  final String backupFolder;
  final List<BackupCardData> backups;
  final List<AdbDeviceData> adbDevices;
  final LiveTransferData? live;
  final VoidCallback? onChangeFolder;
  final void Function(String serial)? onAdbConnect;
  final VoidCallback? onAdbRefresh;
  final void Function(BackupCardData)? onRestore;
  final void Function(BackupCardData)? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Row(
        children: [
          const _Sidebar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backup station', style: t.headlineMedium),
                        const SizedBox(height: 4),
                        Text('Phones on this network or plugged in by USB can back up here.',
                            style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const Spacer(),
                    _StatusPill(text: 'Ready · ${addresses.isEmpty ? hostName : addresses.first}'),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 330,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: _ConnectCard(
                        pairing: pairing,
                        hostName: hostName,
                        adbDevices: adbDevices,
                        onAdbConnect: onAdbConnect,
                        onAdbRefresh: onAdbRefresh,
                      )),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: _LiveCard(live: live)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 32, 4, 14),
                  child: Row(
                    children: [
                      Text('Device backups', style: t.titleLarge),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(backupFolder,
                            style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ),
                      TextButton.icon(onPressed: onChangeFolder, icon: const Icon(Icons.folder_open_rounded), label: const Text('Change folder')),
                    ],
                  ),
                ),
                if (backups.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('No backups yet. Open Mobile Cloner on a phone and tap "Back up to computer".',
                          style: t.bodyMedium)),
                    ),
                  )
                else
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
                    final w = (c.maxWidth - (cols - 1) * 20) / cols;
                    return Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        for (final b in backups)
                          SizedBox(width: w, child: _BackupCard(data: b, onRestore: onRestore, onOpen: onOpenFolder)),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, {bool active = false}) => Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: active ? Colors.white : Colors.white60, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontWeight: FontWeight.w600)),
      ]),
    );
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.copy_all_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Mobile Cloner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          ]),
          const SizedBox(height: 36),
          item(Icons.space_dashboard_rounded, 'Overview', active: true),
          item(Icons.inventory_2_outlined, 'Backups'),
          item(Icons.devices_other_rounded, 'Devices'),
          item(Icons.history_rounded, 'History'),
          const Spacer(),
          item(Icons.settings_outlined, 'Settings'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Icon(Icons.lock_rounded, color: AppColors.teal, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('End-to-end encrypted on your local network',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
    ]),
  );
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.pairing,
    required this.hostName,
    required this.adbDevices,
    this.onAdbConnect,
    this.onAdbRefresh,
  });

  final PairingCode? pairing;
  final String hostName;
  final List<AdbDeviceData> adbDevices;
  final void Function(String serial)? onAdbConnect;
  final VoidCallback? onAdbRefresh;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HeroSurface(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: pairing == null
                ? const SizedBox(width: 150, height: 150)
                : QrImageView(
                    data: pairing!.encode(),
                    size: 150,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF1E1B4B)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF1E1B4B)),
                  ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect a phone', style: t.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text('Wireless: scan the code with Mobile Cloner, or pick "$hostName" from the list on the phone.',
                    style: t.bodyMedium?.copyWith(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 18),
                Row(children: [
                  const Icon(Icons.usb_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('USB cable', style: t.titleSmall?.copyWith(color: Colors.white)),
                  const Spacer(),
                  IconButton(onPressed: onAdbRefresh, color: Colors.white, icon: const Icon(Icons.refresh_rounded, size: 20), tooltip: 'Look for phones'),
                ]),
                const SizedBox(height: 6),
                if (adbDevices.isEmpty)
                  Text('Plug in a phone with USB debugging on. Mobile Cloner installs and opens on it by itself.', style: t.bodySmall?.copyWith(color: Colors.white60))
                else
                  for (final d in adbDevices)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.smartphone_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name ?? d.serial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              if (d.status != null)
                                Text(d.status!, style: t.bodySmall?.copyWith(color: Colors.white70)),
                            ],
                          ),
                        ),
                        d.busy
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              )
                            : d.connected
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text('Linked', style: TextStyle(color: Color(0xFF99F6E4), fontWeight: FontWeight.w700)),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 38),
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.indigo,
                                ),
                                onPressed: () => onAdbConnect?.call(d.serial),
                                child: const Text('Retry'),
                              ),
                      ]),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live});
  final LiveTransferData? live;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final l = live;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: l == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const IconBadge(Icons.cloud_done_outlined, size: 56, color: AppColors.teal),
                  const SizedBox(height: 14),
                  Text('Waiting for a phone', style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text('Transfers show up here live.', style: t.bodySmall?.copyWith(color: muted)),
                ],
              )
            : Row(
                children: [
                  ProgressRing(
                    value: l.fraction,
                    size: 150,
                    stroke: 13,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(l.fraction * 100).round()}%', style: t.headlineMedium),
                      Text(formatSpeed(l.bytesPerSecond), style: t.labelLarge?.copyWith(color: AppColors.indigo)),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backing up', style: t.labelMedium?.copyWith(color: muted, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(l.peer, style: t.titleLarge),
                        const SizedBox(height: 12),
                        _kv(context, 'Copied', '${formatBytes(l.doneBytes)} of ${formatBytes(l.totalBytes)}'),
                        _kv(context, 'Files', '${l.doneFiles} of ${l.totalFiles}'),
                        _kv(context, 'Time left', l.eta == null ? '-' : formatDuration(l.eta!)),
                        const SizedBox(height: 10),
                        BatteryPill(label: 'Phone', status: l.peerStatus),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 84, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
  );
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.data, this.onRestore, this.onOpen});
  final BackupCardData data;
  final void Function(BackupCardData)? onRestore;
  final void Function(BackupCardData)? onOpen;

  static const _colors = [AppColors.indigo, AppColors.teal, AppColors.violet, AppColors.amber, AppColors.rose];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final entries = data.bytesByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.totalBytes == 0 ? 1 : data.totalBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const IconBadge(Icons.smartphone_rounded, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.alias, style: t.titleMedium),
                  Text(data.subtitle, style: t.bodySmall?.copyWith(color: muted)),
                ]),
              ),
              Text(formatBytes(data.totalBytes), style: t.titleMedium),
            ]),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(children: [
                  for (final (i, e) in entries.indexed)
                    Expanded(flex: (e.value * 1000 ~/ total).clamp(1, 1000), child: Container(color: _colors[i % _colors.length])),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final (i, e) in entries.indexed)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${categoryLabel(e.key)} ${formatBytes(e.value)}', style: t.bodySmall),
                ]),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: muted),
              const SizedBox(width: 6),
              Text(data.lastBackup, style: t.bodySmall?.copyWith(color: muted)),
              const Spacer(),
              TextButton(onPressed: () => onOpen?.call(data), child: const Text('Open')),
              const SizedBox(width: 4),
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => onRestore?.call(data),
                child: const Text('Restore'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
