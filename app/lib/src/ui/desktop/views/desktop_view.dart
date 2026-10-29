import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n.dart';
import '../../../services/format.dart';
import '../../theme.dart';
import '../../widgets/credits.dart';
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

  /// What the automatic setup is doing or needs ("Installing HK Cloner").
  final String? status;
  final bool busy;
}

/// Main panels the sidebar switches between.
enum DesktopSection { overview, backups, devices, history, settings }

/// A phone seen on the network.
class NearbyDeviceData {
  const NearbyDeviceData({required this.name, required this.address});
  final String name;
  final String address;
}

/// One past backup of one category ("Photos from Pixel 7").
class HistoryEntry {
  const HistoryEntry({required this.title, required this.detail, required this.when});
  final String title;
  final String detail;
  final String when;
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
    this.section = DesktopSection.overview,
    this.nearby = const [],
    this.history = const [],
    this.appVersion = '',
    this.language = 'ar',
    this.live,
    this.onSection,
    this.onChangeFolder,
    this.onAdbConnect,
    this.onAdbRefresh,
    this.onRestore,
    this.onOpenFolder,
    this.onPreview,
    this.onDelete,
    this.onLanguage,
  });

  final String hostName;
  final List<String> addresses;
  final PairingCode? pairing;
  final String backupFolder;
  final List<BackupCardData> backups;
  final List<AdbDeviceData> adbDevices;
  final DesktopSection section;
  final List<NearbyDeviceData> nearby;
  final List<HistoryEntry> history;
  final String appVersion;

  /// `ar` or `en`.
  final String language;
  final LiveTransferData? live;
  final void Function(DesktopSection)? onSection;
  final VoidCallback? onChangeFolder;
  final void Function(String serial)? onAdbConnect;
  final VoidCallback? onAdbRefresh;
  final void Function(BackupCardData)? onRestore;
  final void Function(BackupCardData)? onOpenFolder;
  final void Function(BackupCardData)? onPreview;
  final void Function(BackupCardData)? onDelete;
  final ValueChanged<String>? onLanguage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(selected: section, onSelect: onSection),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
              children: switch (section) {
                DesktopSection.overview => _overview(context),
                DesktopSection.backups => _backupsPanel(context),
                DesktopSection.devices => _devicesPanel(context),
                DesktopSection.history => _historyPanel(context),
                DesktopSection.settings => _settingsPanel(context),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title, String subtitle) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        _StatusPill(text: S.of(context).readyAt(addresses.isEmpty ? hostName : ltr(addresses.first))),
      ],
    );
  }

  Widget _connectCard() => _ConnectCard(
    pairing: pairing,
    hostName: hostName,
    adbDevices: adbDevices,
    onAdbConnect: onAdbConnect,
    onAdbRefresh: onAdbRefresh,
  );

  List<Widget> _overview(BuildContext context) => [
    _header(context, S.of(context).backupStation, S.of(context).backupStationHint),
    const SizedBox(height: 28),
    LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 1000) {
        return Column(children: [
          _connectCard(),
          const SizedBox(height: 20),
          SizedBox(height: 240, child: _LiveCard(live: live)),
        ]);
      }
      return SizedBox(
        height: 330,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: _connectCard()),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: _LiveCard(live: live)),
          ],
        ),
      );
    }),
    const SizedBox(height: 18),
    ..._backupGrid(context),
  ];

  List<Widget> _backupsPanel(BuildContext context) => [
    _header(context, S.of(context).backups, S.of(context).backupsHint),
    const SizedBox(height: 14),
    ..._backupGrid(context),
  ];

  List<Widget> _backupGrid(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
        child: Row(
          children: [
            Text(S.of(context).deviceBackups, style: t.titleLarge),
            const SizedBox(width: 12),
            Expanded(
              child: Text(ltr(backupFolder),
                  style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ),
            TextButton.icon(
              onPressed: onChangeFolder,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(S.of(context).changeFolder),
            ),
          ],
        ),
      ),
      if (backups.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(S.of(context).noBackupsYet,
                style: t.bodyMedium)),
          ),
        )
      else
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 700 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 20) / cols;
          return Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              for (final b in backups)
                SizedBox(width: w, child: _BackupCard(
                  data: b,
                  onRestore: onRestore,
                  onOpen: onOpenFolder,
                  onPreview: onPreview,
                  onDelete: onDelete,
                )),
            ],
          );
        }),
    ];
  }

  List<Widget> _devicesPanel(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return [
      _header(context, S.of(context).devices, S.of(context).devicesHint),
      const SizedBox(height: 28),
      _connectCard(),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 32, 4, 14),
        child: Text(S.of(context).nearbyOnWifi, style: t.titleLarge),
      ),
      Card(
        child: nearby.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(S.of(context).noPhonesFound,
                    style: t.bodyMedium?.copyWith(color: muted))),
              )
            : Column(children: [
                for (final d in nearby)
                  ListTile(
                    leading: const Icon(Icons.wifi_rounded),
                    title: Text(d.name),
                    subtitle: Text(ltr(d.address)),
                  ),
              ]),
      ),
    ];
  }

  List<Widget> _historyPanel(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return [
      _header(context, S.of(context).history, S.of(context).historyHint),
      const SizedBox(height: 28),
      Card(
        child: history.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(S.of(context).nothingBackedUp, style: t.bodyMedium?.copyWith(color: muted))),
              )
            : Column(children: [
                for (final h in history)
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(h.title),
                    subtitle: Text(h.detail),
                    trailing: Text(h.when, style: t.bodySmall?.copyWith(color: muted)),
                  ),
              ]),
      ),
    ];
  }

  List<Widget> _settingsPanel(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final s = S.of(context);
    return [
      _header(context, s.settings, s.desktopSettingsHint),
      const SizedBox(height: 28),
      Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(s.sectionLanguage),
            trailing: SegmentedButton<String>(
              // Each language in its own script, so either reader finds theirs.
              segments: const [
                ButtonSegment(value: 'ar', label: Text('العربية')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {language},
              onSelectionChanged: onLanguage == null ? null : (v) => onLanguage!(v.single),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_rounded),
            title: Text(s.backupFolder),
            subtitle: Text(backupFolder.isEmpty ? '-' : ltr(backupFolder)),
            trailing: TextButton.icon(
              onPressed: onChangeFolder,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(s.changeFolder),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('HK Cloner'),
            subtitle: Text(appVersion.isEmpty ? s.desktopBackupStation : s.versionLabel(ltr(appVersion))),
          ),
          ListTile(
            leading: const Icon(Icons.computer_rounded),
            title: Text(s.thisComputer),
            subtitle: Text([hostName, ...addresses.map(ltr)].join(' · ')),
          ),
          ListTile(
            leading: const Icon(Icons.lock_rounded),
            title: Text(s.encryption),
            subtitle: Text(s.encryptionHint, style: TextStyle(color: muted)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 32, 4, 14),
        child: Text(s.sectionAbout, style: Theme.of(context).textTheme.titleLarge),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/logo.png', width: 56, height: 56, filterQuality: FilterQuality.medium),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HK Cloner', style: Theme.of(context).textTheme.titleMedium),
                    Text(s.codedAndDesignedBy, style: TextStyle(color: muted)),
                    const SizedBox(height: 8),
                    const Credits(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, this.onSelect});
  final DesktopSection selected;
  final void Function(DesktopSection)? onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, DesktopSection section) {
      final active = section == selected;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: active ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            hoverColor: Colors.white.withValues(alpha: 0.08),
            onTap: () => onSelect?.call(section),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(icon, color: active ? Colors.white : Colors.white60, size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The logo and name sit in the title bar above.
          item(Icons.space_dashboard_rounded, S.of(context).overview, DesktopSection.overview),
          item(Icons.inventory_2_outlined, S.of(context).backups, DesktopSection.backups),
          item(Icons.devices_other_rounded, S.of(context).devices, DesktopSection.devices),
          item(Icons.history_rounded, S.of(context).history, DesktopSection.history),
          const Spacer(),
          item(Icons.settings_outlined, S.of(context).settings, DesktopSection.settings),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: AppColors.teal, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(S.of(context).sidebarEncrypted,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3))),
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
      child: LayoutBuilder(builder: (context, c) {
        final qrSize = (c.maxWidth - 24).clamp(80.0, 150.0);
        final qr = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: pairing == null
              ? SizedBox(width: qrSize, height: qrSize)
              : QrImageView(
                  data: pairing!.encode(),
                  size: qrSize,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF1E1B4B)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF1E1B4B)),
                ),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.of(context).connectAPhone, style: t.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text(S.of(context).connectWireless(hostName),
                style: t.bodyMedium?.copyWith(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.usb_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(S.of(context).usbCable, style: t.titleSmall?.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: onAdbRefresh, color: Colors.white, icon: const Icon(Icons.refresh_rounded, size: 20), tooltip: S.of(context).lookForPhones),
            ]),
            const SizedBox(height: 6),
            if (adbDevices.isEmpty)
              Text(S.of(context).plugInPhone, style: t.bodySmall?.copyWith(color: Colors.white60))
            else
              for (final d in adbDevices)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
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
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(S.of(context).linked,
                                style: const TextStyle(color: Color(0xFF99F6E4), fontWeight: FontWeight.w700)),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.indigo,
                            ),
                            onPressed: () => onAdbConnect?.call(d.serial),
                            child: Text(S.of(context).retry),
                          ),
                  ]),
                ),
          ],
        );
        // Narrow panel: QR on top, text below, no fixed height.
        if (c.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [Center(child: qr), const SizedBox(height: 20), details],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            qr,
            const SizedBox(width: 28),
            Expanded(child: c.hasBoundedHeight ? SingleChildScrollView(child: details) : details),
          ],
        );
      }),
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
                  Text(S.of(context).waitingForPhone, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(S.of(context).transfersShowLive, style: t.bodySmall?.copyWith(color: muted)),
                ],
              )
            : Row(
                children: [
                  ProgressRing(
                    value: l.fraction,
                    size: 150,
                    stroke: 13,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(ltr('${(l.fraction * 100).round()}%'), style: t.headlineMedium),
                      Text(formatSpeed(l.bytesPerSecond), style: t.labelLarge?.copyWith(color: AppColors.indigo)),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.of(context).backingUp, style: t.labelMedium?.copyWith(color: muted, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(l.peer, style: t.titleLarge),
                        const SizedBox(height: 12),
                        _kv(context, S.of(context).copied, S.of(context).sizeOfSize(formatBytes(l.doneBytes), formatBytes(l.totalBytes))),
                        _kv(context, S.of(context).categoryFiles, S.of(context).sizeOfSize(ltr('${l.doneFiles}'), ltr('${l.totalFiles}'))),
                        _kv(context, S.of(context).timeLeft, l.eta == null ? '-' : formatDuration(l.eta!)),
                        const SizedBox(height: 10),
                        BatteryPill(label: S.of(context).phone, status: l.peerStatus),
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
      Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.data, this.onRestore, this.onOpen, this.onPreview, this.onDelete});
  final BackupCardData data;
  final void Function(BackupCardData)? onRestore;
  final void Function(BackupCardData)? onOpen;
  final void Function(BackupCardData)? onPreview;
  final void Function(BackupCardData)? onDelete;

  static const _colors = [AppColors.indigo, AppColors.teal, AppColors.violet, AppColors.amber, AppColors.rose];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final entries = data.bytesByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.totalBytes == 0 ? 1 : data.totalBytes;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onPreview?.call(data),
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
              // Wraps the buttons under the date when the card is narrow.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 16, color: muted),
                    const SizedBox(width: 6),
                    Text(data.lastBackup, style: t.bodySmall?.copyWith(color: muted)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      onPressed: () => onDelete?.call(data),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: S.of(context).deleteBackup,
                    ),
                    TextButton(onPressed: () => onOpen?.call(data), child: Text(S.of(context).open)),
                    const SizedBox(width: 4),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => onRestore?.call(data),
                      child: Text(S.of(context).restore),
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
