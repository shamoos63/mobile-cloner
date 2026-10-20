import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../services/cloner_service.dart';
import '../../sources/contacts_source.dart';
import '../../sources/media_source.dart';
import '../../sources/whatsapp_source.dart';
import 'transfer_page.dart';
import 'views/select_view.dart';

/// Scans what's on this phone and lets the user pick what to send.
class SelectPage extends StatefulWidget {
  const SelectPage({super.key, required this.target});
  final Device target;

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  final service = ClonerService.instance;
  late final media = MediaSource(service.bridge);
  late final contacts = ContactsSource(service.bridge);
  late final whatsapp = WhatsAppSource(service.bridge);

  final Map<ContentCategory, List<OutgoingFile>> _files = {};
  final Map<ContentCategory, int> _counts = {};
  final Set<ContentCategory> _selected = {};
  final Set<ContentCategory> _loading = {};
  final Map<WhatsAppVariant, WhatsAppScan> _wa = {};
  bool _chatsOnly = false;

  @override
  void initState() {
    super.initState();
    _scanAll();
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
    for (final v in WhatsAppVariant.values) {
      _scanWhatsApp(v);
    }
  }

  void _load(ContentCategory c, Future<List<OutgoingFile>> Function() loader) {
    setState(() => _loading.add(c));
    loader().then((files) {
      if (!mounted) return;
      setState(() {
        _files[c] = files;
        _counts.putIfAbsent(c, () => files.length);
        if (files.isNotEmpty) _selected.add(c);
        _loading.remove(c);
      });
    }).catchError((Object _) {
      if (mounted) setState(() => _loading.remove(c));
    });
  }

  void _scanWhatsApp(WhatsAppVariant v) {
    _load(v.category, () async {
      final scan = await whatsapp.scan(v, _chatsOnly ? WhatsAppScope.chatsOnly : WhatsAppScope.full);
      _wa[v] = scan;
      _counts[v.category] = scan.files.length;
      return scan.files;
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
        warning = 'Android 11+ needs your OK to read this folder.';
        action = 'Allow';
        onAction = () async {
          await whatsapp.grantFolder(variant);
          _scanWhatsApp(variant);
        };
      } else if (scan?.newestBackup != null) {
        final age = DateTime.now().difference(scan!.newestBackup!);
        if (age > const Duration(hours: 1)) {
          warning = 'Last chat backup: ${age.inDays > 0 ? '${age.inDays} days' : '${age.inHours} h'} ago';
          action = 'Back up now';
          onAction = () async {
            await whatsapp.openForBackup(variant);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('In WhatsApp: Settings > Chats > Chat backup > Back up. Then come back here.'),
                duration: Duration(seconds: 8),
              ));
            }
          };
        }
      }
    }
    return SelectableItem(
      category: c,
      selected: _selected.contains(c),
      count: _counts[c],
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
      ])
        if (_selected.contains(c)) ...?_files[c],
    ];
    if (files.isEmpty) return;
    service.send(widget.target, files, options: {'whatsAppChatsOnly': _chatsOnly});
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
    ];
    return SelectContentView(
      targetName: widget.target.info.alias,
      targetIsDesktop: widget.target.info.deviceType == DeviceType.desktop,
      items: [for (final c in categories) _item(c)],
      onToggle: (c, v) => setState(() => v ? _selected.add(c) : _selected.remove(c)),
      onStart: _loading.isEmpty && _selected.isNotEmpty ? _start : null,
      whatsAppChatsOnly: _chatsOnly,
      onWhatsAppScope: (v) {
        setState(() => _chatsOnly = v);
        for (final variant in WhatsAppVariant.values) {
          _scanWhatsApp(variant);
        }
      },
    );
  }
}
