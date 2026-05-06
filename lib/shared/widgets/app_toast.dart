import 'dart:async';

import 'package:flutter/material.dart';

enum AppToastVariant { error, info, success }

class AppToast {
  AppToast._();

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String message,
    AppToastVariant variant = AppToastVariant.info,
    Duration? duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _activeEntry
      ?..remove()
      ..dispose();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppToastOverlay(
        duration: duration,
        message: message,
        onDismissed: () {
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          entry.remove();
          entry.dispose();
        },
        variant: variant,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, variant: AppToastVariant.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, variant: AppToastVariant.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message);
  }
}

class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.message,
    required this.onDismissed,
    required this.variant,
    this.duration,
  });

  final Duration? duration;
  final String message;
  final VoidCallback onDismissed;
  final AppToastVariant variant;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.45),
      end: Offset.zero,
    ).animate(curve);

    _controller.forward();
    final duration = widget.duration;
    if (duration != null) {
      _timer = Timer(duration, _dismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.viewPadding.top + 18;

    return Positioned(
      left: 16,
      right: 16,
      top: top,
      child: IgnorePointer(
        ignoring: false,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: _ToastSurface(
                      message: widget.message,
                      variant: widget.variant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastSurface extends StatelessWidget {
  const _ToastSurface({required this.message, required this.variant});

  final String message;
  final AppToastVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = _ToastColors.forVariant(variant);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 21,
                  height: 21,
                  child: Icon(
                    colors.icon,
                    color: colors.iconForeground,
                    size: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastColors {
  const _ToastColors({
    required this.border,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.surface,
    required this.text,
  });

  final Color border;
  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final Color surface;
  final Color text;

  static _ToastColors forVariant(AppToastVariant variant) {
    switch (variant) {
      case AppToastVariant.error:
        return const _ToastColors(
          border: Color(0xFF18181B),
          icon: Icons.close_rounded,
          iconBackground: Colors.white,
          iconForeground: Color(0xFFDC2626),
          surface: Color(0xFF050505),
          text: Colors.white,
        );
      case AppToastVariant.success:
        return const _ToastColors(
          border: Color(0xFF18181B),
          icon: Icons.check_rounded,
          iconBackground: Colors.white,
          iconForeground: Color(0xFF050505),
          surface: Color(0xFF050505),
          text: Colors.white,
        );
      case AppToastVariant.info:
        return const _ToastColors(
          border: Color(0xFF18181B),
          icon: Icons.info_outline_rounded,
          iconBackground: Colors.white,
          iconForeground: Color(0xFF050505),
          surface: Color(0xFF050505),
          text: Colors.white,
        );
    }
  }
}
