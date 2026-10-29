import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n.dart';
import '../../../platform/android_bridge.dart';
import '../../../services/format.dart';
import '../../theme.dart';

enum AppSort { name, size }

/// Picks which installed apps to copy: search, sort, select all / none,
/// with the count and total size of the selection. Apps Android won't let
/// us read are shown but can't be ticked.
class AppPickerView extends StatefulWidget {
  const AppPickerView({
    super.key,
    required this.apps,
    required this.initial,
    required this.iconFor,
    required this.onDone,
  });

  /// Null while the list is loading.
  final List<InstalledApp>? apps;
  final Set<String> initial;
  final Future<Uint8List?> Function(String package) iconFor;
  final ValueChanged<Set<String>> onDone;

  @override
  State<AppPickerView> createState() => _AppPickerViewState();
}

class _AppPickerViewState extends State<AppPickerView> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';
  AppSort _sort = AppSort.name;

  List<InstalledApp> get _visible {
    final q = _query.trim().toLowerCase();
    final list = [
      for (final a in widget.apps ?? const <InstalledApp>[])
        if (q.isEmpty || a.label.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q)) a,
    ];
    list.sort(switch (_sort) {
      AppSort.name => (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      AppSort.size => (a, b) => b.sizeBytes.compareTo(a.sizeBytes),
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final apps = widget.apps;
    final visible = _visible;
    final chosen = [for (final a in apps ?? const <InstalledApp>[]) if (_selected.contains(a.packageName)) a];
    final total = chosen.fold<int>(0, (sum, a) => sum + a.sizeBytes);
    return Scaffold(
      appBar: AppBar(title: Text(s.chooseApps), leading: const BackButton()),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: s.searchApps,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<AppSort>(
                  style: SegmentedButton.styleFrom(minimumSize: const Size(0, 40)),
                  segments: [
                    ButtonSegment(value: AppSort.name, label: Text(s.sortName)),
                    ButtonSegment(value: AppSort.size, label: Text(s.sortSize)),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (v) => setState(() => _sort = v.single),
                ),
                TextButton(
                  onPressed: apps == null
                      ? null
                      : () => setState(() => _selected.addAll([for (final a in visible) if (a.readable) a.packageName])),
                  child: Text(s.selectAll),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.removeAll([for (final a in visible) a.packageName])),
                  child: Text(s.selectNone),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(s.appsOnlyNote, style: t.bodySmall)),
            ]),
          ),
          Expanded(
            child: apps == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(s.loadingApps),
                    ]),
                  )
                : visible.isEmpty
                ? Center(child: Text(s.noAppsFound, style: t.bodyMedium?.copyWith(color: muted)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final a = visible[i];
                      return CheckboxListTile(
                        key: ValueKey(a.packageName),
                        value: _selected.contains(a.packageName),
                        onChanged: a.readable
                            ? (v) => setState(() => v == true ? _selected.add(a.packageName) : _selected.remove(a.packageName))
                            : null,
                        secondary: _AppIcon(package: a.packageName, iconFor: widget.iconFor),
                        title: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          a.readable ? '${ltr(a.versionName)} · ${formatBytes(a.sizeBytes)}' : s.appUnreadable,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
            ),
            child: Row(children: [
              Expanded(child: Text(s.appsSelected(chosen.length, formatBytes(total)), style: t.titleSmall)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                onPressed: () => widget.onDone({for (final a in chosen) a.packageName}),
                child: Text(s.done),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Fetches the icon once, not on every rebuild of the list.
class _AppIcon extends StatefulWidget {
  const _AppIcon({required this.package, required this.iconFor});
  final String package;
  final Future<Uint8List?> Function(String package) iconFor;

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  late final Future<Uint8List?> _icon = widget.iconFor(widget.package);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: FutureBuilder<Uint8List?>(
      future: _icon,
      builder: (context, snap) => snap.data == null
          ? const Icon(Icons.android_rounded, size: 32)
          : Image.memory(snap.data!, width: 40, height: 40),
    ),
  );
}
