import 'dart:async';

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../services/cloner_service.dart';
import '../../sources/rebuild.dart';
import 'connect_page.dart';
import 'views/transfer_view.dart';

/// Live view of the current send, including the paused state and the ways
/// to continue.
class TransferPage extends StatefulWidget {
  const TransferPage({super.key, this.resumeOnOpen = false});
  final bool resumeOnOpen;

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final service = ClonerService.instance;
  String? _error;

  /// When every byte had gone out without the receiver confirming yet.
  DateTime? _finishingSince;
  Timer? _tick;

  static const _finishingPatience = Duration(seconds: 30);

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// All sent, not confirmed: after a while offer Resume (pause + resume
  /// skips what the receiver has and sends the finish again).
  Future<void> _resumeStuck() async {
    _finishingSince = null;
    service.pauseSend();
    // The job stops on its own schedule; resume once it has.
    for (var i = 0; i < 50 && service.sendState == SendState.sending; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _resume();
  }

  @override
  void initState() {
    super.initState();
    if (widget.resumeOnOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  Future<void> _resume({Device? via}) async {
    setState(() => _error = null);
    try {
      final cp = service.checkpoint;
      final files = service.lastFiles.isEmpty && cp != null ? await rebuildFiles(service.bridge, cp) : null;
      await service.resume(target: via, files: files);
    } catch (e) {
      // Not reachable on the old path: let the user pick another way.
      if (via == null) {
        await _reconnect();
      } else {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _reconnect() async {
    final cp = service.checkpoint;
    final device = await Navigator.push<Device>(
      context,
      MaterialPageRoute(builder: (_) => ConnectPage(mustMatch: cp?.peerFingerprint)),
    );
    if (device != null) await _resume(via: device);
  }

  List<CategoryProgress> _categories() {
    final cp = service.checkpoint;
    final files = service.lastFiles;
    final total = <ContentCategory, int>{};
    final done = <ContentCategory, int>{};
    for (final f in files) {
      total[f.dto.category] = (total[f.dto.category] ?? 0) + 1;
      if (cp?.doneFileIds.contains(f.dto.id) ?? service.sendState == SendState.done) {
        done[f.dto.category] = (done[f.dto.category] ?? 0) + 1;
      }
    }
    return [for (final e in total.entries) CategoryProgress(e.key, done[e.key] ?? 0, e.value)];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final pr = service.sendProgress;
        final cp = service.checkpoint;
        final peer = service.sendTarget?.info.alias ?? cp?.peerAlias ?? S.of(context).deviceFallbackName;
        final interrupted = service.sendState == SendState.interrupted || service.sendState == SendState.failed;
        final done = service.sendState == SendState.done;
        final allSent = pr != null && pr.totalFiles > 0 && pr.doneFiles >= pr.totalFiles;
        final phase = done
            ? TransferPhase.done
            : interrupted
            ? TransferPhase.interrupted
            : allSent
            ? TransferPhase.finishing
            : TransferPhase.sending;
        if (phase == TransferPhase.finishing) {
          _finishingSince ??= DateTime.now();
          _tick ??= Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted) setState(() {});
          });
        } else {
          _finishingSince = null;
          _tick?.cancel();
          _tick = null;
        }
        final stuck = _finishingSince != null && DateTime.now().difference(_finishingSince!) > _finishingPatience;
        final reason = interrupted
            ? (_error ??
                (service.sendState == SendState.failed
                    ? S.of(context).transferFailed('${service.sendResult?.error ?? S.of(context).unknownError}')
                    : service.interruptText(service.sendResult?.interruptReason)))
            : null;
        return TransferView(
          title: done ? S.of(context).allDone : S.of(context).sendingTo(peer),
          peerName: peer,
          fraction: done ? 1 : (pr?.fraction ?? 0),
          doneBytes: pr?.sentBytes ?? 0,
          totalBytes: pr?.totalBytes ?? cp?.totalBytes ?? 0,
          bytesPerSecond: pr?.bytesPerSecond ?? 0,
          eta: pr?.eta,
          doneFiles: pr?.doneFiles ?? cp?.doneFiles ?? 0,
          totalFiles: pr?.totalFiles ?? cp?.totalFiles ?? 0,
          currentFile: pr?.currentFile,
          categories: _categories(),
          myStatus: service.localStatus,
          peerStatus: pr?.peerStatus,
          interruptedReason: reason,
          onPause: service.pauseSend,
          onCancel: () async {
            await service.cancelSend();
            if (context.mounted) Navigator.pop(context);
          },
          onResume: phase == TransferPhase.finishing ? _resumeStuck : () => _resume(),
          onReconnect: _reconnect,
          phase: phase,
          finishingStuck: stuck,
          onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
        );
      },
    );
  }
}
