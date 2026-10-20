import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../../services/format.dart';
import '../../theme.dart';
import '../../widgets/labels.dart';
import '../../widgets/visuals.dart';

class CategoryProgress {
  const CategoryProgress(this.category, this.done, this.total);
  final ContentCategory category;
  final int done;
  final int total;
}

/// Live transfer screen. Also renders the interrupted state with the ways
/// to continue.
class TransferView extends StatelessWidget {
  const TransferView({
    super.key,
    required this.title,
    required this.peerName,
    required this.fraction,
    required this.doneBytes,
    required this.totalBytes,
    required this.bytesPerSecond,
    required this.doneFiles,
    required this.totalFiles,
    this.eta,
    this.currentFile,
    this.categories = const [],
    this.myStatus,
    this.peerStatus,
    this.interruptedReason,
    this.onPause,
    this.onCancel,
    this.onResume,
    this.onReconnect,
  });

  final String title;
  final String peerName;
  final double fraction;
  final int doneBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final int doneFiles;
  final int totalFiles;
  final Duration? eta;
  final String? currentFile;
  final List<CategoryProgress> categories;
  final PeerStatus? myStatus;
  final PeerStatus? peerStatus;

  /// Non-null when the transfer stopped part way.
  final String? interruptedReason;
  final VoidCallback? onPause;
  final VoidCallback? onCancel;
  final VoidCallback? onResume;
  final VoidCallback? onReconnect;

  bool get interrupted => interruptedReason != null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(title), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  children: [
                    ProgressRing(
                      value: fraction,
                      size: 220,
                      stroke: 18,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(fraction * 100).toStringAsFixed(fraction < 0.1 ? 1 : 0)}%', style: t.displayMedium),
                          Text(
                            interrupted ? 'Paused' : formatSpeed(bytesPerSecond),
                            style: t.titleMedium?.copyWith(color: interrupted ? AppColors.amber : AppColors.indigo),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _Metric(label: 'Time left', value: interrupted || eta == null ? '-' : formatDuration(eta!)),
                        _Metric(label: 'Copied', value: formatBytes(doneBytes)),
                        _Metric(label: 'Total', value: formatBytes(totalBytes)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BatteryPill(label: 'This phone', status: myStatus),
                        const SizedBox(width: 8),
                        BatteryPill(label: peerName, status: peerStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (interrupted) ...[
              const SizedBox(height: 16),
              _InterruptedCard(reason: interruptedReason!, onResume: onResume, onReconnect: onReconnect),
            ],
            const SectionLabel('Progress'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            IconBadge(categoryIcon(c.category), size: 40,
                                color: c.done == c.total ? AppColors.teal : AppColors.indigo),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(categoryLabel(c.category), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    const Spacer(),
                                    Text('${c.done} / ${c.total}', style: t.bodySmall?.copyWith(color: muted)),
                                  ]),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: c.total == 0 ? 1 : c.done / c.total,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                    color: c.done == c.total ? AppColors.teal : AppColors.indigo,
                                  ),
                                ],
                              ),
                            ),
                            if (c.done == c.total) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 20),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (currentFile != null && !interrupted)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text('$doneFiles of $totalFiles · $currentFile',
                    style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 20),
            if (!interrupted)
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: onPause, icon: const Icon(Icons.pause_rounded), label: const Text('Pause'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Cancel'))),
              ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: muted),
                const SizedBox(width: 6),
                Text('Encrypted · progress saved continuously', style: t.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(children: [
        Text(value, style: t.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _InterruptedCard extends StatelessWidget {
  const _InterruptedCard({required this.reason, this.onResume, this.onReconnect});
  final String reason;
  final VoidCallback? onResume;
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      color: AppColors.amber.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(reason.toLowerCase().contains('battery') ? Icons.battery_alert_rounded : Icons.wifi_off_rounded,
                  color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text(reason, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Text('Nothing is lost. Resume here, or switch to hotspot, USB cable or a QR code.', style: t.bodySmall),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onResume, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Resume')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onReconnect,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Continue another way'),
            ),
          ],
        ),
      ),
    );
  }
}
