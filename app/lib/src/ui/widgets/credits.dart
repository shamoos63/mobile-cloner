import 'dart:io';

import 'package:flutter/material.dart';

import '../../platform/android_bridge.dart';

const authorName = 'Eng. Hisham Khateeb';
const authorWebsite = 'https://hishamkhateeb.com';
const authorTelegram = '@xavior963';
const authorTelegramUrl = 'https://t.me/xavior963';

/// Opens [url] in the browser (or the Telegram app for t.me links).
Future<void> openLink(String url) async {
  if (Platform.isAndroid) {
    await AndroidBridge.instance.openUrl(url);
  } else {
    final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    await Process.run(cmd, [url]);
  }
}

/// "Made with ♥ by ..." plus the website and Telegram links.
class Credits extends StatelessWidget {
  const Credits({super.key, this.compact = false});

  /// Phone footer: centered, small text.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final heart = Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'Made with '),
        const TextSpan(text: '♥', style: TextStyle(color: Color(0xFFE11D48))),
        const TextSpan(text: ' by $authorName'),
      ]),
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: (compact ? t.bodySmall : t.bodyMedium)?.copyWith(color: compact ? muted : null),
    );
    final links = Wrap(
      alignment: compact ? WrapAlignment.center : WrapAlignment.start,
      spacing: 4,
      children: [
        _link(Icons.language_rounded, 'hishamkhateeb.com', authorWebsite),
        _link(Icons.send_rounded, authorTelegram, authorTelegramUrl),
      ],
    );
    return Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [heart, const SizedBox(height: 4), links],
    );
  }

  Widget _link(IconData icon, String label, String url) => TextButton.icon(
    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
    onPressed: () => openLink(url),
    icon: Icon(icon, size: 16),
    label: Text(label),
  );
}
