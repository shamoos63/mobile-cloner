import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/cloner_service.dart';
import '../../services/format.dart';
import 'labels.dart';

/// Shows the Accept / Decline dialog whenever a sender asks to transfer.
class IncomingRequestListener extends StatefulWidget {
  const IncomingRequestListener({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<IncomingRequestListener> createState() => _IncomingRequestListenerState();
}

class _IncomingRequestListenerState extends State<IncomingRequestListener> {
  final service = ClonerService.instance;
  IncomingRequest? _showing;

  @override
  void initState() {
    super.initState();
    service.addListener(_check);
  }

  @override
  void dispose() {
    service.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final req = service.pendingRequest;
    if (req == null || identical(req, _showing)) return;
    _showing = req;
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).wantsToSend(req.sender.info.alias)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${S.of(context).itemsCount(req.files.length)} · ${formatBytes(req.totalBytes)}'),
            const SizedBox(height: 12),
            for (final e in req.countByCategory.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(e.key)),
                title: Text(categoryLabel(e.key)),
                trailing: Text(ltr('${e.value}')),
              ),
            if (req.files.any((f) => f.category.isWhatsApp))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(service.isAndroid
                    ? S.of(context).whatsappGoesToFolder
                    : S.of(context).storedInBackupFolder),
              ),
            if (!req.sender.info.isCloner)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(service.isAndroid ? S.of(context).sentFromLocalSendDownloads : S.of(context).sentFromLocalSend),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.of(context).decline)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).accept),
          ),
        ],
      ),
    ).then((ok) => req.respond(ok ?? false));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
