import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The window's own title bar (the OS one is hidden): drag to move,
/// double-click to maximize, and minimize / maximize / close buttons.
class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({super.key});

  static const double height = 40;

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((m) {
      if (mounted) setState(() => _maximized = m);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        height: DesktopTitleBar.height,
        decoration: const BoxDecoration(
          // Same colours as the sidebar, so the two read as one panel.
          gradient: LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)]),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _toggleMaximize,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Image.asset('assets/logo.png', width: 22, height: 22, filterQuality: FilterQuality.medium),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'HK Cloner',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            _WindowButton(icon: Icons.remove_rounded, tooltip: 'Minimize', onPressed: windowManager.minimize),
            _WindowButton(
              icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
              iconSize: _maximized ? 13 : 15,
              tooltip: _maximized ? 'Restore' : 'Maximize',
              onPressed: _toggleMaximize,
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              hover: const Color(0xFFE81123),
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 16,
    this.hover,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final Color? hover;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onPressed,
        hoverColor: hover ?? Colors.white.withValues(alpha: 0.1),
        highlightColor: (hover ?? Colors.white).withValues(alpha: 0.2),
        splashColor: Colors.transparent,
        child: SizedBox(
          width: 46,
          height: DesktopTitleBar.height,
          child: Icon(icon, size: iconSize, color: Colors.white70),
        ),
      ),
    );
  }
}
