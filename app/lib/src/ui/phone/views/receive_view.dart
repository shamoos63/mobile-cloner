import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n.dart';
import '../../theme.dart';
import '../../widgets/visuals.dart';

/// "Ready to receive": pairing QR plus the connection modes.
class ReceiveView extends StatelessWidget {
  const ReceiveView({
    super.key,
    required this.deviceName,
    required this.pairing,
    required this.mode,
    required this.onMode,
    this.needsWhatsAppAccess = false,
    this.onGrantWhatsApp,
    this.modeHint,
    this.notice,
    this.modeActionLabel,
    this.onModeAction,
  });

  final String deviceName;
  final PairingCode? pairing;
  final ConnectionMode mode;
  final ValueChanged<ConnectionMode> onMode;
  final bool needsWhatsAppAccess;
  final VoidCallback? onGrantWhatsApp;
  final String? modeHint;

  /// Shown above the connection modes (the permission card).
  final Widget? notice;

  /// A button under [modeHint], e.g. switching to the hotspot.
  final String? modeActionLabel;
  final VoidCallback? onModeAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.receive), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            HeroSurface(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                    child: pairing == null
                        ? const SizedBox(width: 196, height: 196, child: Center(child: CircularProgressIndicator()))
                        : QrImageView(
                            data: pairing!.encode(),
                            size: 196,
                            padding: EdgeInsets.zero,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF1E1B4B)),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Text(deviceName, style: t.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(s.scanThisWithOldPhone,
                      style: t.bodyMedium?.copyWith(color: Colors.white70), textAlign: TextAlign.center),
                  if (pairing != null) ...[
                    const SizedBox(height: 12),
                    Text(ltr(pairing!.addresses.take(2).join('  ·  ')),
                        style: t.labelMedium?.copyWith(color: Colors.white60, letterSpacing: 0.5)),
                  ],
                ],
              ),
            ),
            if (needsWhatsAppAccess) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const IconBadge(Icons.chat_outlined, color: AppColors.teal, size: 44),
                  title: Text(s.allowWhatsappFolder, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.allowWhatsappFolderHint),
                  trailing: FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: onGrantWhatsApp,
                    child: Text(s.allow),
                  ),
                ),
              ),
            ],
            ?notice,
            SectionLabel(s.howConnected),
            _ModeTile(
              mode: ConnectionMode.wifi,
              current: mode,
              onTap: onMode,
              icon: Icons.wifi_rounded,
              title: s.modeWifi,
              subtitle: s.modeWifiHint,
            ),
            _ModeTile(
              mode: ConnectionMode.hotspot,
              current: mode,
              onTap: onMode,
              icon: Icons.wifi_tethering_rounded,
              title: s.modeHotspot,
              subtitle: s.modeHotspotHint,
            ),
            _ModeTile(
              mode: ConnectionMode.usbTethering,
              current: mode,
              onTap: onMode,
              icon: Icons.usb_rounded,
              title: s.usbCable,
              subtitle: s.modeCableHint,
            ),
            if (modeHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(modeHint!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            if (modeActionLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: onModeAction,
                    child: Text(modeActionLabel!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.current,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ConnectionMode mode;
  final ConnectionMode current;
  final ValueChanged<ConnectionMode> onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final selected = mode == current;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.indigo : Theme.of(context).dividerColor.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => onTap(mode),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: IconBadge(icon, size: 42, color: selected ? AppColors.indigo : Colors.blueGrey),
          title: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.indigo : null),
        ),
      ),
    );
  }
}
