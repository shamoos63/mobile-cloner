import 'package:flutter/material.dart';

import '../../platform/android_bridge.dart';
import '../../sources/apps_source.dart';
import 'views/app_picker_view.dart';

/// Loads the installed apps and lets the user pick; pops the chosen
/// package names (null when backed out).
class AppPickerPage extends StatefulWidget {
  const AppPickerPage({super.key, required this.source, required this.apps, required this.initial});

  final AppsSource source;
  final Future<List<InstalledApp>> apps;
  final Set<String> initial;

  @override
  State<AppPickerPage> createState() => _AppPickerPageState();
}

class _AppPickerPageState extends State<AppPickerPage> {
  List<InstalledApp>? _apps;

  @override
  void initState() {
    super.initState();
    widget.apps.then((a) {
      if (mounted) setState(() => _apps = a);
    }).catchError((Object _) {
      if (mounted) setState(() => _apps = const []);
    });
  }

  @override
  Widget build(BuildContext context) => AppPickerView(
    apps: _apps,
    initial: widget.initial,
    iconFor: widget.source.icon,
    onDone: (chosen) => Navigator.pop(context, chosen),
  );
}
