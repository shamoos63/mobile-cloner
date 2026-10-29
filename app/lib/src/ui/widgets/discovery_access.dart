import 'package:flutter/material.dart';

import '../../l10n.dart';
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
        final s = S.of(context);
        final sdk = service.android?.sdkInt ?? 33;
        final name = sdk >= 33 ? s.nearbyDevicesPermission : s.locationPermission;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconBadge(Icons.radar_rounded, size: 44, color: AppColors.indigo),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(s.allowPermissionToFind(name),
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                [
                  s.discoveryWhy,
                  if (sdk < 33) s.discoveryLocationNote(service.android?.release ?? ''),
                  if (state == PermissionState.blocked) s.discoveryBlocked(name),
                ].join(' '),
                style: t.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 8, children: [
                if (state == PermissionState.denied)
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _recheck(ask: true),
                    child: Text(s.grant),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: service.bridge.openAppSettings,
                  child: Text(s.openSettings),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
