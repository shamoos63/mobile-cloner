import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../platform/android_bridge.dart';
import '../../services/app_settings.dart';
import '../../services/cloner_service.dart';
import '../../version.dart';
import 'views/settings_view.dart';

/// Phone settings screen: saves to [AppSettings], asks Android for
/// permissions, and re-reads them when the user comes back from Settings.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final service = ClonerService.instance;
  final settings = AppSettings.instance;
  late final AppLifecycleListener _lifecycle;

  /// Permission row -> the Android permissions it stands for.
  List<(PermissionItem, List<String>)> _rows = [];
  bool _allFiles = true;

  int get _sdk => service.android!.sdkInt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _load);
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  List<(IconData, String, String, List<String>)> get _wanted => [
    (
      Icons.radar_rounded,
      _sdk >= 33 ? tr.nearbyDevicesPermission : tr.locationPermission,
      _sdk >= 33 ? tr.permNearbyPurpose : tr.permLocationPurpose,
      AndroidPermission.discovery(_sdk),
    ),
    (Icons.photo_library_outlined, tr.permPhotos, tr.permPhotosPurpose, AndroidPermission.media(_sdk)),
    (
      Icons.contacts_outlined,
      tr.categoryContacts,
      tr.permContactsPurpose,
      [AndroidPermission.readContacts, AndroidPermission.writeContacts],
    ),
    (Icons.qr_code_scanner_rounded, tr.permCamera, tr.permCameraPurpose, [AndroidPermission.camera]),
    if (_sdk >= 33)
      (Icons.notifications_outlined, tr.permNotifications, tr.permNotificationsPurpose, [AndroidPermission.notifications]),
  ];

  Future<void> _load() async {
    final wanted = _wanted;
    final states = await service.bridge.permissionState([for (final w in wanted) ...w.$4]);
    final allFiles = _sdk < 30 || await service.bridge.hasAllFilesAccess();
    if (!mounted) return;
    setState(() {
      _allFiles = allFiles;
      _rows = [
        for (final (icon, title, purpose, names) in wanted)
          (
            PermissionItem(icon: icon, title: title, purpose: purpose, state: _worst([for (final n in names) states[n]!])),
            names,
          ),
      ];
    });
    await service.ensureDiscoveryAccess(ask: false);
  }

  static PermissionState _worst(List<PermissionState> states) => states.contains(PermissionState.blocked)
      ? PermissionState.blocked
      : states.contains(PermissionState.denied)
      ? PermissionState.denied
      : PermissionState.granted;

  Future<void> _grant(PermissionItem item) async {
    if (item.title == tr.permAllFiles) {
      await service.bridge.requestAllFilesAccess();
      return; // Android's page; re-read on resume.
    }
    if (item.state == PermissionState.blocked) {
      await service.bridge.openAppSettings();
      return;
    }
    final names = _rows.firstWhere((r) => r.$1.title == item.title).$2;
    await service.bridge.requestPermissions(names);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PhoneSettingsView(
        deviceName: service.self.alias,
        defaultDeviceName: service.defaultDeviceName,
        themeMode: settings.themeMode,
        language: settings.language,
        keepScreenOn: settings.keepScreenOn,
        permissions: [
          for (final r in _rows) r.$1,
          if (_sdk >= 30)
            PermissionItem(
              icon: Icons.chat_outlined,
              title: tr.permAllFiles,
              purpose: tr.permAllFilesPurpose,
              state: _allFiles ? PermissionState.granted : PermissionState.denied,
            ),
        ],
        version: '$appVersionName ($appVersionCode)',
        onRename: service.rename,
        onThemeMode: settings.setThemeMode,
        onLanguage: settings.setLanguage,
        onKeepScreenOn: settings.setKeepScreenOn,
        onGrant: _grant,
        onOpenAppSettings: service.bridge.openAppSettings,
      ),
    );
  }
}
