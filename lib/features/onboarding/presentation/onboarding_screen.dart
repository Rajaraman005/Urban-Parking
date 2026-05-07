import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/legal_consent_text.dart';
import '../data/onboarding_slides.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _statusBarColor = Colors.black;
  static const _bodyBackgroundColor = Colors.black;
  static const _panelColor = Colors.white;
  static const _primaryActionColor = Color(0xFF070708);
  static const _secondaryBorderColor = Color(0xFF171719);
  static const _legalTextColor = Color(0xFF565656);
  static const _buttonHeight = 52.0;
  static const _autoPlayInterval = Duration(milliseconds: 4200);
  static const _slideDuration = Duration(milliseconds: 820);
  static const _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: _statusBarColor,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  final PageController _pageController = PageController();
  Timer? _autoPlayTimer;
  int _currentPage = 0;
  bool _didPrecacheImages = false;
  bool _imagesReady = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _applyStatusBarStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyStatusBarStyle();
    if (!_didPrecacheImages) {
      _didPrecacheImages = true;
      unawaited(_precacheSlideImages());
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _precacheSlideImages() async {
    final imageFutures = onboardingSlides.map((slide) {
      return precacheImage(
        AssetImage(slide.image),
        context,
        onError: (_, _) {},
      );
    });

    try {
      await Future.wait(imageFutures);
    } on Object {
      // Individual slide renderers still fall back to black on image errors.
    }

    if (!mounted) return;
    setState(() => _imagesReady = true);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
      if (!_imagesReady ||
          !mounted ||
          !_pageController.hasClients ||
          _isAnimating) {
        return;
      }
      final nextPage = (_currentPage + 1) % onboardingSlides.length;
      unawaited(_animateToPage(nextPage));
    });
  }

  Future<void> _animateToPage(int page) async {
    if (!_imagesReady || !_pageController.hasClients) return;
    _isAnimating = true;
    try {
      await _pageController.animateToPage(
        page,
        duration: _slideDuration,
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _isAnimating = false;
    }
  }

  void _applyStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(_systemUiStyle);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: AppScreen(
        padded: false,
        backgroundColor: _bodyBackgroundColor,
        safeAreaBottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: _bodyBackgroundColor,
              child: _imagesReady
                  ? PageView.builder(
                      controller: _pageController,
                      clipBehavior: Clip.hardEdge,
                      itemCount: onboardingSlides.length,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                      },
                      itemBuilder: (context, index) {
                        return _OnboardingSlideView(
                          slide: onboardingSlides[index],
                        );
                      },
                    )
                  : const SizedBox.expand(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                decoration: const BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: _buttonHeight,
                        child: FilledButton.icon(
                          style: _primaryActionButtonStyle,
                          onPressed: () => context.go('/auth?mode=signup'),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 20,
                          ),
                          label: const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ActionDivider(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: _buttonHeight,
                        child: OutlinedButton.icon(
                          style: _secondaryActionButtonStyle,
                          onPressed: () => context.go('/auth?mode=login'),
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text('Log in'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const LegalConsentText(textColor: _legalTextColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _primaryActionButtonStyle = FilledButton.styleFrom(
    backgroundColor: _primaryActionColor,
    foregroundColor: _panelColor,
    iconColor: _panelColor,
    minimumSize: const Size.fromHeight(_buttonHeight),
    fixedSize: const Size.fromHeight(_buttonHeight),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      height: 1,
    ),
  );

  static final ButtonStyle _secondaryActionButtonStyle =
      OutlinedButton.styleFrom(
        backgroundColor: _panelColor,
        foregroundColor: _primaryActionColor,
        iconColor: _primaryActionColor,
        minimumSize: const Size.fromHeight(_buttonHeight),
        fixedSize: const Size.fromHeight(_buttonHeight),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: _secondaryBorderColor, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      );
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide});

  static const _heroCopyBottomPadding = 266.0;
  static const _heroCopyMaxWidth = 334.0;

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            slide.image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) {
              return const ColoredBox(color: Colors.black);
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.76),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                22,
                0,
                22,
                _heroCopyBottomPadding,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _heroCopyMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      slide.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 18 / 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, color: Color(0xFFE1E1E1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF8A8A8A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1, color: Color(0xFFE1E1E1))),
      ],
    );
  }
}
