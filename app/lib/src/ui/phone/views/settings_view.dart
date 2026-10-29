import 'package:flutter/material.dart';

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
    required this.keepScreenOn,
    required this.permissions,
    required this.version,
    required this.onRename,
    required this.onThemeMode,
    required this.onKeepScreenOn,
    required this.onGrant,
    required this.onOpenAppSettings,
  });

  final String deviceName;
  final String defaultDeviceName;
  final ThemeMode themeMode;
  final bool keepScreenOn;
  final List<PermissionItem> permissions;
  final String version;
  final ValueChanged<String?> onRename;
  final ValueChanged<ThemeMode> onThemeMode;
  final ValueChanged<bool> onKeepScreenOn;
  final ValueChanged<PermissionItem> onGrant;
  final VoidCallback onOpenAppSettings;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: deviceName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device name'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: controller, autofocus: true, maxLength: 40),
          Text('Other phones and computers see this name. Leave it empty to use "$defaultDeviceName".'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null) onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const SectionLabel('This phone'),
            Card(
              child: ListTile(
                onTap: () => _rename(context),
                leading: const IconBadge(Icons.badge_outlined, size: 40, color: AppColors.indigo),
                title: const Text('Device name'),
                subtitle: Text(deviceName),
                trailing: const Icon(Icons.edit_outlined),
              ),
            ),
            const SectionLabel('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => onThemeMode(s.single),
                ),
              ),
            ),
            const SectionLabel('Transfers'),
            Card(
              child: SwitchListTile(
                value: keepScreenOn,
                onChanged: onKeepScreenOn,
                secondary: const IconBadge(Icons.screen_lock_portrait_outlined, size: 40, color: AppColors.teal),
                title: const Text('Keep screen on'),
                subtitle: const Text('While sending or receiving. Some phones slow down Wi-Fi when the screen is off.'),
              ),
            ),
            const SectionLabel('Permissions'),
            Card(
              child: Column(children: [
                for (final p in permissions)
                  ListTile(
                    leading: IconBadge(p.icon, size: 40, color: p.state == PermissionState.granted ? AppColors.teal : AppColors.amber),
                    title: Text(p.title),
                    subtitle: Text(p.purpose),
                    trailing: p.state == PermissionState.granted
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.teal, semanticLabel: 'Allowed')
                        : FilledButton.tonal(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () => onGrant(p),
                            child: Text(p.state == PermissionState.blocked ? 'Settings' : 'Allow'),
                          ),
                  ),
                ListTile(
                  onTap: onOpenAppSettings,
                  leading: const IconBadge(Icons.settings_applications_outlined, size: 40, color: Colors.blueGrey),
                  title: const Text('Open Android app settings'),
                  subtitle: const Text('Permissions, storage and notifications for HK Cloner'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                ),
              ]),
            ),
            const SectionLabel('About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Image.asset('assets/logo.png', width: 40, height: 40, filterQuality: FilterQuality.medium),
                    const SizedBox(width: 12),
                    Expanded(child: Text('HK Cloner', style: t.titleMedium)),
                    Text('Version $version', style: t.bodySmall?.copyWith(color: muted)),
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
