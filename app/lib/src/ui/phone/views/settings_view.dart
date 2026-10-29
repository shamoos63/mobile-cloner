import 'package:flutter/material.dart';

import '../../../l10n.dart';
import '../../../platform/android_bridge.dart';
import '../../theme.dart';
import '../../widgets/credits.dart';
import '../../widgets/visuals.dart';

/// One permission row: what it is for and whether it is granted.
class PermissionItem {
  const PermissionItem({required this.icon, required this.title, required this.purpose, required this.state});
  final IconData icon;
  final String title;
  final String purpose;
  final PermissionState state;
}

/// Phone settings: name, appearance, transfers, permissions, about.
class PhoneSettingsView extends StatelessWidget {
  const PhoneSettingsView({
    super.key,
    required this.deviceName,
    required this.defaultDeviceName,
    required this.themeMode,
    required this.language,
    required this.keepScreenOn,
    required this.permissions,
    required this.version,
    required this.onRename,
    required this.onThemeMode,
    required this.onLanguage,
    required this.onKeepScreenOn,
    required this.onGrant,
    required this.onOpenAppSettings,
  });

  final String deviceName;
  final String defaultDeviceName;
  final ThemeMode themeMode;

  /// `ar` or `en`.
  final String language;
  final bool keepScreenOn;
  final List<PermissionItem> permissions;
  final String version;
  final ValueChanged<String?> onRename;
  final ValueChanged<ThemeMode> onThemeMode;
  final ValueChanged<String> onLanguage;
  final ValueChanged<bool> onKeepScreenOn;
  final ValueChanged<PermissionItem> onGrant;
  final VoidCallback onOpenAppSettings;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: deviceName);
    final s = S.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deviceName),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: controller, autofocus: true, maxLength: 40),
          Text(s.deviceNameHint(defaultDeviceName)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(s.save)),
        ],
      ),
    );
    if (name != null) onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            SectionLabel(s.sectionThisPhone),
            Card(
              child: ListTile(
                onTap: () => _rename(context),
                leading: const IconBadge(Icons.badge_outlined, size: 40, color: AppColors.indigo),
                title: Text(s.deviceName),
                subtitle: Text(deviceName),
                trailing: const Icon(Icons.edit_outlined),
              ),
            ),
            SectionLabel(s.sectionLanguage),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SegmentedButton<String>(
                  // Each language in its own script, so either reader finds theirs.
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {language},
                  onSelectionChanged: (v) => onLanguage(v.single),
                ),
              ),
            ),
            SectionLabel(s.sectionAppearance),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(s.themeSystem), icon: const Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(value: ThemeMode.light, label: Text(s.themeLight), icon: const Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(s.themeDark), icon: const Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (v) => onThemeMode(v.single),
                ),
              ),
            ),
            SectionLabel(s.sectionTransfers),
            Card(
              child: SwitchListTile(
                value: keepScreenOn,
                onChanged: onKeepScreenOn,
                secondary: const IconBadge(Icons.screen_lock_portrait_outlined, size: 40, color: AppColors.teal),
                title: Text(s.keepScreenOn),
                subtitle: Text(s.keepScreenOnHint),
              ),
            ),
            SectionLabel(s.sectionPermissions),
            Card(
              child: Column(children: [
                for (final p in permissions)
                  ListTile(
                    leading: IconBadge(p.icon, size: 40, color: p.state == PermissionState.granted ? AppColors.teal : AppColors.amber),
                    title: Text(p.title),
                    subtitle: Text(p.purpose),
                    trailing: p.state == PermissionState.granted
                        ? Icon(Icons.check_circle_rounded, color: AppColors.teal, semanticLabel: s.allowed)
                        : FilledButton.tonal(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () => onGrant(p),
                            child: Text(p.state == PermissionState.blocked ? s.settings : s.allow),
                          ),
                  ),
                ListTile(
                  onTap: onOpenAppSettings,
                  leading: const IconBadge(Icons.settings_applications_outlined, size: 40, color: Colors.blueGrey),
                  title: Text(s.openAndroidAppSettings),
                  subtitle: Text(s.openAndroidAppSettingsHint),
                  trailing: const Icon(Icons.open_in_new_rounded),
                ),
              ]),
            ),
            SectionLabel(s.sectionAbout),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Image.asset('assets/logo.png', width: 40, height: 40, filterQuality: FilterQuality.medium),
                    const SizedBox(width: 12),
                    Expanded(child: Text('HK Cloner', style: t.titleMedium)),
                    Text(s.versionLabel(ltr(version)), style: t.bodySmall?.copyWith(color: muted)),
                  ]),
                  const SizedBox(height: 14),
                  const Credits(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
