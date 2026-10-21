import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/credits.dart';
import '../../widgets/visuals.dart';

class ResumeInfo {
  const ResumeInfo({required this.peer, required this.doneFiles, required this.totalFiles, required this.reason});
  final String peer;
  final int doneFiles;
  final int totalFiles;
  final String reason;
}

class NearbyPeer {
  const NearbyPeer({required this.name, required this.isDesktop, this.subtitle});
  final String name;
  final bool isDesktop;
  final String? subtitle;
}

/// Phone start screen.
class PhoneHomeView extends StatelessWidget {
  const PhoneHomeView({
    super.key,
    required this.deviceName,
    required this.osLabel,
    required this.myStatus,
    required this.nearby,
    required this.onSend,
    required this.onReceive,
    required this.onBackup,
    required this.onRestore,
    this.resume,
    this.onResume,
    this.onDiscardResume,
  });

  final String deviceName;
  final String osLabel;
  final PeerStatus? myStatus;
  final List<NearbyPeer> nearby;
  final ResumeInfo? resume;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback? onResume;
  final VoidCallback? onDiscardResume;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Image.asset('assets/logo.png', width: 40, height: 40, filterQuality: FilterQuality.medium),
                const SizedBox(width: 10),
                Text('HK Cloner', style: t.titleLarge),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
              ],
            ),
            const SizedBox(height: 16),
            HeroSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Move everything\nto your new phone', style: t.headlineMedium?.copyWith(color: Colors.white, height: 1.15)),
                  const SizedBox(height: 10),
                  Text(
                    'Photos, videos, contacts and WhatsApp chats. Over Wi-Fi, hotspot or cable, and it picks up where it left off.',
                    style: t.bodyMedium?.copyWith(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroTag(icon: Icons.smartphone_rounded, text: '$deviceName · $osLabel'),
                      BatteryPill(label: 'Battery', status: myStatus, onDark: true),
                    ],
                  ),
                ],
              ),
            ),
            if (resume != null) ...[
              const SizedBox(height: 16),
              _ResumeCard(info: resume!, onResume: onResume, onDiscard: onDiscardResume),
            ],
            const SectionLabel('Phone to phone'),
            Row(
              children: [
                Expanded(child: _BigAction(
                  icon: Icons.north_east_rounded,
                  color: AppColors.indigo,
                  title: 'Send',
                  subtitle: 'This is my old phone',
                  onTap: onSend,
                )),
                const SizedBox(width: 12),
                Expanded(child: _BigAction(
                  icon: Icons.south_west_rounded,
                  color: AppColors.teal,
                  title: 'Receive',
                  subtitle: 'This is my new phone',
                  onTap: onReceive,
                )),
              ],
            ),
            const SectionLabel('Computer'),
            Card(
              child: Column(
                children: [
                  _ListAction(icon: Icons.cloud_upload_outlined, color: AppColors.violet, title: 'Back up to computer',
                      subtitle: 'Incremental, only new files are copied', onTap: onBackup),
                  const Divider(height: 1, indent: 76),
                  _ListAction(icon: Icons.settings_backup_restore_rounded, color: AppColors.amber, title: 'Restore from computer',
                      subtitle: 'Bring a backup onto this phone', onTap: onRestore),
                ],
              ),
            ),
            if (nearby.isNotEmpty) ...[
              const SectionLabel('Nearby'),
              Card(
                child: Column(
                  children: [
                    for (final (i, peer) in nearby.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 76),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: IconBadge(peer.isDesktop ? Icons.computer_rounded : Icons.smartphone_rounded,
                            color: peer.isDesktop ? AppColors.violet : AppColors.indigo, size: 44),
                        title: Text(peer.name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: peer.subtitle == null ? null : Text(peer.subtitle!),
                        trailing: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            const Credits(compact: true),
          ],
        ),
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.white),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon, color: color, size: 52),
              const SizedBox(height: 28),
              Text(title, style: t.titleLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListAction extends StatelessWidget {
  const _ListAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: IconBadge(icon, color: color, size: 44),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.info, this.onResume, this.onDiscard});
  final ResumeInfo info;
  final VoidCallback? onResume;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fraction = info.totalFiles == 0 ? 0.0 : info.doneFiles / info.totalFiles;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(
              value: fraction,
              size: 56,
              stroke: 6,
              child: Text('${(fraction * 100).round()}%', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unfinished transfer to ${info.peer}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${info.doneFiles} of ${info.totalFiles} files · ${info.reason}',
                      style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: onResume,
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}
