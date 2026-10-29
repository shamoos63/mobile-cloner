import 'package:flutter/material.dart';

import '../../platform/android_bridge.dart';
import '../../services/cloner_service.dart';
import '../theme.dart';
import 'visuals.dart';

/// Shown instead of a silent empty device list when the phone may not look
/// for nearby devices. Re-reads the permission when the user comes back
/// from Settings.
class DiscoveryAccessCard extends StatefulWidget {
  const DiscoveryAccessCard({super.key});

  @override
  State<DiscoveryAccessCard> createState() => _DiscoveryAccessCardState();
}

class _DiscoveryAccessCardState extends State<DiscoveryAccessCard> {
  final service = ClonerService.instance;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _recheck(ask: false));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _recheck({required bool ask}) async {
    if (await service.ensureDiscoveryAccess(ask: ask)) service.refresh(scan: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.discoveryAccess;
        if (state == PermissionState.granted) return const SizedBox.shrink();
        final t = Theme.of(context).textTheme;
        final sdk = service.android?.sdkInt ?? 33;
        final name = sdk >= 33 ? 'Nearby devices' : 'Location';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconBadge(Icons.radar_rounded, size: 44, color: AppColors.indigo),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Allow "$name" to find the other phone',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                [
                  'Without it, phones on the same Wi-Fi or a USB cable cannot see each other.',
                  if (sdk < 33)
                    'Android ${service.android?.release ?? ''} calls this permission Location. '
                        'HK Cloner never reads where you are.',
                  if (state == PermissionState.blocked)
                    'Android will not ask again. Open Settings > Permissions and allow $name.',
                ].join(' '),
                style: t.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 8, children: [
                if (state == PermissionState.denied)
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _recheck(ask: true),
                    child: const Text('Grant'),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: service.bridge.openAppSettings,
                  child: const Text('Open settings'),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
