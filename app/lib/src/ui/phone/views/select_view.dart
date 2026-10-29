import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../../services/format.dart';
import '../../../l10n.dart';
import '../../theme.dart';
import '../../widgets/labels.dart';
import '../../widgets/visuals.dart';

class SelectableItem {
  const SelectableItem({
    required this.category,
    required this.selected,
    this.count,
    this.bytes,
    this.note,
    this.warning,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final ContentCategory category;
  final bool selected;
  final int? count;
  final int? bytes;
  final String? note;

  /// Shown in amber, e.g. "Last WhatsApp backup was 3 days ago".
  final String? warning;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;
}

/// "What do you want to move?" screen.
class SelectContentView extends StatelessWidget {
  const SelectContentView({
    super.key,
    required this.targetName,
    required this.targetIsDesktop,
    required this.items,
    required this.onToggle,
    required this.onStart,
    this.whatsAppChatsOnly = false,
    this.onWhatsAppScope,
  });

  final String targetName;
  final bool targetIsDesktop;
  final List<SelectableItem> items;
  final void Function(ContentCategory c, bool selected) onToggle;
  final VoidCallback? onStart;
  final bool whatsAppChatsOnly;
  final ValueChanged<bool>? onWhatsAppScope;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selected = items.where((i) => i.selected);
    final totalBytes = selected.fold(0, (a, i) => a + (i.bytes ?? 0));
    final totalCount = selected.fold(0, (a, i) => a + (i.count ?? 0));
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.chooseWhatToMove), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: IconBadge(targetIsDesktop ? Icons.computer_rounded : Icons.smartphone_rounded,
                          color: AppColors.teal, size: 44),
                      title: Text(targetName, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      subtitle: Text(s.connectedEncrypted),
                      trailing: const Icon(Icons.lock_rounded, size: 18, color: AppColors.teal),
                    ),
                  ),
                  SectionLabel(s.sectionContent),
                  for (final item in items) ...[
                    _ItemCard(item: item, onToggle: (v) => onToggle(item.category, v)),
                    if (item.category == ContentCategory.whatsapp && item.selected && onWhatsAppScope != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(value: false, label: Text(s.chatsAndMedia), icon: const Icon(Icons.perm_media_outlined)),
                            ButtonSegment(value: true, label: Text(s.chatsOnly), icon: const Icon(Icons.chat_bubble_outline)),
                          ],
                          selected: {whatsAppChatsOnly},
                          onSelectionChanged: (v) => onWhatsAppScope!(v.first),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
              ),
              child: Column(
                children: [
                  Row(children: [
                    Text(s.itemsCount(totalCount), style: t.titleSmall),
                    const Spacer(),
                    Text(formatBytes(totalBytes), style: t.titleSmall?.copyWith(color: AppColors.indigo)),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onStart, child: Text(targetIsDesktop ? s.startBackup : s.startTransfer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onToggle});
  final SelectableItem item;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final details = [
      if (item.count != null)
        item.category == ContentCategory.contacts ? S.of(context).contactsCount(item.count!) : S.of(context).filesCount(item.count!),
      if (item.bytes != null && item.bytes! > 0) formatBytes(item.bytes!),
      if (item.note != null) item.note!,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onToggle(!item.selected),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(categoryIcon(item.category), size: 44,
                      color: item.category.isWhatsApp ? AppColors.teal : AppColors.indigo),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(categoryLabel(item.category), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        item.loading
                            ? Row(children: [
                                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: muted)),
                                const SizedBox(width: 8),
                                Text(S.of(context).scanning, style: t.bodySmall?.copyWith(color: muted)),
                              ])
                            : Text(details, style: t.bodySmall?.copyWith(color: muted)),
                      ],
                    ),
                  ),
                  Checkbox(value: item.selected, onChanged: (v) => onToggle(v ?? false)),
                ],
              ),
              if (item.warning != null || item.actionLabel != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.warning ?? '', style: t.bodySmall)),
                      if (item.actionLabel != null)
                        TextButton(onPressed: item.onAction, child: Text(item.actionLabel!)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
