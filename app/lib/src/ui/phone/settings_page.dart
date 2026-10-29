import 'package:flutter/material.dart';

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
      _sdk >= 33 ? 'Nearby devices' : 'Location',
      _sdk >= 33 ? 'Find the other phone on Wi-Fi and cable' : 'Find the other phone on Wi-Fi (never reads where you are)',
      AndroidPermission.discovery(_sdk),
    ),
    (Icons.photo_library_outlined, 'Photos and videos', 'Send and receive your gallery', AndroidPermission.media(_sdk)),
    (
      Icons.contacts_outlined,
      'Contacts',
      'Send and receive contacts',
      [AndroidPermission.readContacts, AndroidPermission.writeContacts],
    ),
    (Icons.qr_code_scanner_rounded, 'Camera', 'Scan the pairing QR code', [AndroidPermission.camera]),
    if (_sdk >= 33)
      (Icons.notifications_outlined, 'Notifications', 'Show progress while a transfer runs', [AndroidPermission.notifications]),
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
    if (item.title == _allFilesTitle) {
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

  static const _allFilesTitle = 'All files (WhatsApp)';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PhoneSettingsView(
        deviceName: service.self.alias,
        defaultDeviceName: service.defaultDeviceName,
        themeMode: settings.themeMode,
        keepScreenOn: settings.keepScreenOn,
        permissions: [
          for (final r in _rows) r.$1,
          if (_sdk >= 30)
            PermissionItem(
              icon: Icons.chat_outlined,
              title: _allFilesTitle,
              purpose: 'Read and restore WhatsApp chats on Android 11 and newer',
              state: _allFiles ? PermissionState.granted : PermissionState.denied,
            ),
        ],
        version: '$appVersionName ($appVersionCode)',
        onRename: service.rename,
        onThemeMode: settings.setThemeMode,
        onKeepScreenOn: settings.setKeepScreenOn,
        onGrant: _grant,
        onOpenAppSettings: service.bridge.openAppSettings,
      ),
    );
  }
}
