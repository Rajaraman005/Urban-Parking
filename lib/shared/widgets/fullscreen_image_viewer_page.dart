import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/screen_capture_guard.dart';

Future<void> showFullscreenImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          FullscreenImageViewerPage(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        );
      },
    ),
  );
}

class FullscreenImageViewerPage extends StatefulWidget {
  const FullscreenImageViewerPage({
    required this.imageUrls,
    super.key,
    this.initialIndex = 0,
  }) : assert(imageUrls.length > 0, 'imageUrls cannot be empty');

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<FullscreenImageViewerPage> createState() =>
      _FullscreenImageViewerPageState();
}

class _FullscreenImageViewerPageState extends State<FullscreenImageViewerPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late int _activeIndex;

  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _activeIndex);
    unawaited(ScreenCaptureGuard.acquire());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    unawaited(ScreenCaptureGuard.release());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ScreenCaptureGuard.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    if (_activeIndex == index) return;
                    setState(() => _activeIndex = index);
                  },
                  itemBuilder: (context, index) => Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: const EdgeInsets.all(24),
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrls[index],
                        fit: BoxFit.contain,
                        placeholder: (context, _) => const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (context, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 20,
                child: _ViewerActionButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: 12,
                right: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '${_activeIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.imageUrls.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var index = 0;
                              index < widget.imageUrls.length;
                              index++
                            )
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                width: index == _activeIndex ? 18 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: index == _activeIndex ? 1 : 0.44,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                      ),
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

class _ViewerActionButton extends StatelessWidget {
  const _ViewerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
