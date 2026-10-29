import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../platform/android_bridge.dart';
import '../../services/cloner_service.dart';
import '../../sources/apps_source.dart';
import '../../sources/contacts_source.dart';
import '../../sources/media_source.dart';
import '../../sources/wallpaper_source.dart';
import '../../sources/whatsapp_source.dart';
import 'app_picker_page.dart';
import 'transfer_page.dart';
import 'views/select_view.dart';

/// Scans what's on this phone and lets the user pick what to send.
class SelectPage extends StatefulWidget {
  const SelectPage({super.key, required this.target});
  final Device target;

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> with WidgetsBindingObserver {
  final service = ClonerService.instance;
  late final media = MediaSource(service.bridge);
  late final contacts = ContactsSource(service.bridge);
  late final whatsapp = WhatsAppSource(service.bridge);
  late final wallpaper = WallpaperSource(service.bridge);
  late final appsSource = AppsSource(service.bridge);

  final Map<ContentCategory, List<OutgoingFile>> _files = {};
  final Map<ContentCategory, int> _counts = {};
  final Set<ContentCategory> _selected = {};
  final Set<ContentCategory> _loading = {};
  final Map<WhatsAppVariant, WhatsAppScan> _wa = {};
  bool _chatsOnly = false;
  bool _wallpaperDenied = false;

  /// Installed apps, listed the first time Apps is ticked.
  Future<List<InstalledApp>>? _appList;
  Set<String> _chosenApps = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the All-files access screen: try the wallpaper again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wallpaperDenied && !_loading.contains(ContentCategory.wallpaper)) {
      _scanWallpaper();
    }
  }

  Future<void> _scanAll() async {
    if (await media.requestAccess()) {
      for (final c in [ContentCategory.photos, ContentCategory.videos]) {
        _load(c, () async => media.files(c));
      }
    }
    if (await contacts.requestAccess()) {
      _load(ContentCategory.contacts, () async {
        final r = await contacts.export();
        _counts[ContentCategory.contacts] = r.count;
        return [r.file];
      });
    }
    _scanWallpaper();
    // WhatsApp folders are slow to walk: scanned when first ticked.
  }

  /// Off by default: changing the new phone's wallpaper is opt-in.
  void _scanWallpaper() {
    _load(ContentCategory.wallpaper, select: false, () async {
      final r = await wallpaper.export();
      _wallpaperDenied = r.denied;
      return r.files;
    });
  }

  void _load(ContentCategory c, Future<List<OutgoingFile>> Function() loader, {bool select = true}) {
    setState(() => _loading.add(c));
    loader().then((files) {
      if (!mounted) return;
      setState(() {
        _files[c] = files;
        _counts.putIfAbsent(c, () => files.length);
        if (files.isEmpty) {
          _selected.remove(c);
        } else if (select) {
          _selected.add(c);
        }
        _loading.remove(c);
      });
    }).catchError((Object _) {
      if (mounted) setState(() => _loading.remove(c));
    });
  }

  void _toggle(ContentCategory c, bool on) {
    if (c == ContentCategory.apps) {
      on ? _chooseApps() : setState(() => _selected.remove(c));
      return;
    }
    setState(() => on ? _selected.add(c) : _selected.remove(c));
    final variant = WhatsAppVariant.fromCategory(c);
    if (on && variant != null && !_wa.containsKey(variant) && !_loading.contains(c)) {
      _scanWhatsApp(variant);
    }
  }

  void _scanWhatsApp(WhatsAppVariant v) {
    _load(v.category, () async {
      final scan = await whatsapp.scan(v, _chatsOnly ? WhatsAppScope.chatsOnly : WhatsAppScope.full);
      _wa[v] = scan;
      _counts[v.category] = scan.files.length;
      return scan.files;
    });
  }

  /// Opens the app picker; the chosen apps' APKs become the Apps files.
  Future<void> _chooseApps() async {
    final list = _appList ??= appsSource.list();
    final chosen = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(builder: (_) => AppPickerPage(source: appsSource, apps: list, initial: _chosenApps)),
    );
    if (chosen == null || !mounted) return;
    setState(() => _chosenApps = chosen);
    if (chosen.isEmpty) {
      setState(() {
        _selected.remove(ContentCategory.apps);
        _files.remove(ContentCategory.apps);
      });
      return;
    }
    final apps = [for (final a in await list) if (chosen.contains(a.packageName)) a];
    _load(ContentCategory.apps, () async {
      _counts[ContentCategory.apps] = apps.length;
      return appsSource.files(apps);
    });
  }

  SelectableItem _item(ContentCategory c) {
    final files = _files[c] ?? const [];
    final variant = WhatsAppVariant.fromCategory(c);
    String? warning;
    String? action;
    VoidCallback? onAction;
    if (variant != null) {
      final scan = _wa[variant];
      if (scan?.access == WhatsAppAccess.needsGrant) {
        warning = S.of(context).whatsappNeedsGrant;
        action = S.of(context).allow;
        onAction = () async {
          await whatsapp.grantFolder(variant);
          _scanWhatsApp(variant);
        };
      } else if (scan?.newestBackup != null) {
        final age = DateTime.now().difference(scan!.newestBackup!);
        if (age > const Duration(hours: 1)) {
          warning = age.inDays > 0 ? S.of(context).lastChatBackupDays(age.inDays) : S.of(context).lastChatBackupHours(age.inHours);
          action = S.of(context).backUpNow;
          onAction = () async {
            await whatsapp.openForBackup(variant);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(S.of(context).whatsappBackupSteps),
                duration: const Duration(seconds: 8),
              ));
            }
          };
        }
      }
    }
    if (c == ContentCategory.apps) {
      warning = S.of(context).appsOnlyNote;
      action = S.of(context).chooseApps;
      onAction = _chooseApps;
    }
    if (c == ContentCategory.wallpaper && _wallpaperDenied) {
      warning = S.of(context).wallpaperNeedsAllFiles;
      action = S.of(context).allow;
      onAction = service.bridge.requestAllFilesAccess;
    }
    return SelectableItem(
      category: c,
      selected: _selected.contains(c),
      count: _counts[c],
      note: variant != null && !_wa.containsKey(variant) && !_loading.contains(c) ? S.of(context).tickToScan : null,
      bytes: c == ContentCategory.contacts ? null : files.fold<int>(0, (a, f) => a + f.dto.size),
      loading: _loading.contains(c),
      warning: warning,
      actionLabel: action,
      onAction: onAction,
    );
  }

  Future<void> _start() async {
    final files = [
      // Small, high-value things first so an early drop still moves them.
      for (final c in [
        ContentCategory.contacts,
        ContentCategory.whatsapp,
        ContentCategory.whatsappBusiness,
        ContentCategory.photos,
        ContentCategory.videos,
        ContentCategory.wallpaper,
        // Largest and least urgent: last.
        ContentCategory.apps,
      ])
        if (_selected.contains(c)) ...?_files[c],
    ];
    if (files.isEmpty) return;
    service.send(widget.target, files, options: {
      'whatsAppChatsOnly': _chatsOnly,
      // Lets a restarted app rebuild the Apps files for the same packages.
      if (_selected.contains(ContentCategory.apps)) 'apps': [..._chosenApps],
    });
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TransferPage()));
  }

  @override
  Widget build(BuildContext context) {
    const categories = [
      ContentCategory.photos,
      ContentCategory.videos,
      ContentCategory.contacts,
      ContentCategory.whatsapp,
      ContentCategory.whatsappBusiness,
      ContentCategory.wallpaper,
      ContentCategory.apps,
    ];
    return SelectContentView(
      targetName: widget.target.info.alias,
      targetIsDesktop: widget.target.info.deviceType == DeviceType.desktop,
      items: [for (final c in categories) _item(c)],
      onToggle: _toggle,
      onStart: _loading.isEmpty && _selected.isNotEmpty ? _start : null,
      whatsAppChatsOnly: _chatsOnly,
      onWhatsAppScope: (v) {
        setState(() => _chatsOnly = v);
        // Only rescan what was already scanned; the rest scans when ticked.
        for (final variant in WhatsAppVariant.values) {
          if (_wa.containsKey(variant)) _scanWhatsApp(variant);
        }
      },
    );
  }
}
