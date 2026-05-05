import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'fullscreen_image_viewer_page.dart';

class ListingDetailsPage extends StatefulWidget {
  const ListingDetailsPage({
    required this.address,
    required this.description,
    required this.heroImageUrls,
    required this.onBack,
    required this.onPrimaryAction,
    required this.priceText,
    required this.primaryActionLabel,
    required this.stats,
    required this.title,
    super.key,
    this.extraSections = const [],
    this.galleryImageUrls = const [],
    this.isPrimaryActionLoading = false,
    this.listingLabel = 'For Rent',
    this.bottomNavigationBar,
    this.onFavorite,
    this.onSecondaryAction,
    this.onShare,
    this.ratingText,
    this.reviewText,
    this.sectionsBeforeDescription = const [],
    this.secondaryActionLabel,
    this.topTitle = 'Property Details',
  });

  final String address;
  final Widget? bottomNavigationBar;
  final String description;
  final List<Widget> extraSections;
  final List<String> galleryImageUrls;
  final List<String> heroImageUrls;
  final bool isPrimaryActionLoading;
  final String listingLabel;
  final VoidCallback onBack;
  final VoidCallback? onFavorite;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onShare;
  final String priceText;
  final String primaryActionLabel;
  final String? ratingText;
  final String? reviewText;
  final List<Widget> sectionsBeforeDescription;
  final String? secondaryActionLabel;
  final List<ListingDetailStat> stats;
  final String title;
  final String topTitle;

  @override
  State<ListingDetailsPage> createState() => _ListingDetailsPageState();
}

class ListingDetailStat {
  const ListingDetailStat(this.label, {this.icon});

  final IconData? icon;
  final String label;
}

class _ListingDetailsPageState extends State<ListingDetailsPage> {
  static const _fallbackImageUrl =
      'https://images.unsplash.com/photo-1506521781263-d8422e82f27a';
  static const _heroPageSeed = 1000;
  static const _autoSlideInterval = Duration(seconds: 4);
  static const _slideDuration = Duration(milliseconds: 620);

  late final PageController _heroController;
  Timer? _heroTimer;
  int _activeHeroIndex = 0;
  int _heroPage = 0;

  @override
  void initState() {
    super.initState();
    _heroPage = _initialPageFor(_heroUrls.length);
    _heroController = PageController(initialPage: _heroPage);
    _restartHeroTimer();
  }

  @override
  void didUpdateWidget(covariant ListingDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrls = _imageUrlsFor([
      ...oldWidget.heroImageUrls,
      ...oldWidget.galleryImageUrls,
    ]);
    final newUrls = _heroUrls;
    if (!_sameUrls(oldUrls, newUrls)) {
      _activeHeroIndex = 0;
      _heroPage = _initialPageFor(newUrls.length);
      if (_heroController.hasClients) {
        _heroController.jumpToPage(_heroPage);
      }
      _restartHeroTimer();
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroUrls = _heroUrls;
    final footerBottomSpacing = widget.bottomNavigationBar == null
        ? MediaQuery.paddingOf(context).bottom + 12
        : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: _DetailsTopBar(
                onBack: widget.onBack,
                onFavorite: widget.onFavorite,
                onShare: widget.onShare,
                title: widget.topTitle,
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                bottom: widget.bottomNavigationBar == null,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    _HeroGallery(
                      activeIndex: _activeHeroIndex,
                      controller: _heroController,
                      imageUrls: heroUrls,
                      onChanged: (page) => _syncHeroPage(page, heroUrls.length),
                      onImageTap: _openHeroViewer,
                    ),
                    const SizedBox(height: 18),
                    _TitleRatingPriceBlock(
                      priceText: widget.priceText,
                      ratingText: widget.ratingText,
                      reviewText: widget.reviewText,
                      title: widget.title,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _FooterActionSection(
                      isPrimaryLoading: widget.isPrimaryActionLoading,
                      onPrimaryAction: widget.onPrimaryAction,
                      onSecondaryAction: widget.onSecondaryAction,
                      primaryActionLabel: widget.primaryActionLabel,
                      secondaryActionLabel: widget.secondaryActionLabel,
                    ),
                    const SizedBox(height: 18),
                    _StatsWrap(stats: widget.stats),
                    if (widget.sectionsBeforeDescription.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      for (
                        var index = 0;
                        index < widget.sectionsBeforeDescription.length;
                        index++
                      ) ...[
                        widget.sectionsBeforeDescription[index],
                        if (index < widget.sectionsBeforeDescription.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                    const SizedBox(height: 20),
                    _SectionText(
                      title: 'Description',
                      body: widget.description,
                    ),
                    for (final section in widget.extraSections) ...[
                      const SizedBox(height: 18),
                      section,
                    ],
                    SizedBox(height: footerBottomSpacing),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _heroUrls =>
      _imageUrlsFor([...widget.heroImageUrls, ...widget.galleryImageUrls]);

  int _initialPageFor(int imageCount) {
    if (imageCount < 2) return 0;
    return _heroPageSeed - (_heroPageSeed % imageCount);
  }

  void _restartHeroTimer() {
    _heroTimer?.cancel();
    if (_heroUrls.length < 2) return;
    _heroTimer = Timer.periodic(_autoSlideInterval, (_) => _showNextHero());
  }

  void _showNextHero() {
    final urls = _heroUrls;
    if (!_heroController.hasClients || urls.length < 2) return;
    final nextPage = _heroPage + 1;
    _heroPage = nextPage;
    unawaited(
      _heroController.animateToPage(
        nextPage,
        duration: _slideDuration,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  void _syncHeroPage(int page, int imageCount) {
    if (imageCount <= 0) return;
    _heroPage = page;
    final nextIndex = page % imageCount;
    if (nextIndex == _activeHeroIndex) return;
    setState(() => _activeHeroIndex = nextIndex);
  }

  Future<void> _openHeroViewer(int initialIndex) async {
    _heroTimer?.cancel();
    await showFullscreenImageViewer(
      context,
      imageUrls: _heroUrls,
      initialIndex: initialIndex,
    );
    if (!mounted) return;
    _restartHeroTimer();
  }

  List<String> _imageUrlsFor(List<String> rawUrls) {
    final urls = <String>{};
    for (final rawUrl in rawUrls) {
      final url = rawUrl.trim();
      if (url.isNotEmpty) urls.add(url);
    }
    if (urls.isEmpty) urls.add(_fallbackImageUrl);
    return urls.toList(growable: false);
  }

  bool _sameUrls(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _DetailsTopBar extends StatelessWidget {
  const _DetailsTopBar({
    required this.onBack,
    required this.onFavorite,
    required this.onShare,
    required this.title,
  });

  final VoidCallback onBack;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _TopBarActionButton(
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              borderColor: Colors.white.withValues(alpha: 0.18),
              icon: Icons.arrow_back_rounded,
              iconColor: Colors.white,
              onTap: onBack,
              tooltip: 'Back',
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onShare != null) ...[
                  _TopBarActionButton(
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    borderColor: Colors.white.withValues(alpha: 0.18),
                    icon: Icons.ios_share_rounded,
                    iconColor: Colors.white,
                    onTap: onShare,
                    tooltip: 'Share',
                  ),
                  const SizedBox(width: 8),
                ],
                _TopBarActionButton(
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  borderColor: Colors.white.withValues(alpha: 0.18),
                  icon: Icons.favorite_border_rounded,
                  iconColor: Colors.white,
                  onTap: onFavorite,
                  tooltip: 'Favorite',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.activeIndex,
    required this.controller,
    required this.imageUrls,
    required this.onChanged,
    required this.onImageTap,
  });

  final int activeIndex;
  final PageController controller;
  final List<String> imageUrls;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onImageTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1.48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: controller,
                onPageChanged: onChanged,
                itemBuilder: (context, index) {
                  final imageIndex = index % imageUrls.length;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onImageTap(imageIndex),
                    child: _NetworkCoverImage(imageUrl: imageUrls[imageIndex]),
                  );
                },
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0x1A000000),
                      ],
                      stops: [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
              if (imageUrls.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: IgnorePointer(
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var index = 0;
                                index < imageUrls.length;
                                index++
                              )
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  width: index == activeIndex ? 17 : 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: index == activeIndex ? 1 : 0.64,
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
                ),
              if (imageUrls.length <= 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 13,
                  child: IgnorePointer(
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const SizedBox(width: 18, height: 5),
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

class _TitleRatingPriceBlock extends StatelessWidget {
  const _TitleRatingPriceBlock({
    required this.priceText,
    required this.ratingText,
    required this.reviewText,
    required this.title,
  });

  final String priceText;
  final String? ratingText;
  final String? reviewText;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: 0,
                ),
              ),
              if (ratingText != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC107),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ratingText!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    if (reviewText != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '($reviewText)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 98, maxWidth: 118),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                priceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsWrap extends StatelessWidget {
  const _StatsWrap({required this.stats});

  final List<ListingDetailStat> stats;

  @override
  Widget build(BuildContext context) {
    final visibleStats = stats.take(3).toList(growable: false);
    if (visibleStats.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var index = 0; index < visibleStats.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _FeatureStatTile(stat: visibleStats[index])),
        ],
      ],
    );
  }
}

class _FeatureStatTile extends StatelessWidget {
  const _FeatureStatTile({required this.stat});

  final ListingDetailStat stat;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stat.icon ?? Icons.check_circle_outline_rounded,
              color: Colors.black,
              size: 21,
            ),
            const SizedBox(height: 7),
            Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({
    this.backgroundColor = Colors.white,
    this.borderColor,
    required this.icon,
    this.iconColor = Colors.black,
    required this.onTap,
    required this.tooltip,
  });

  final Color backgroundColor;
  final Color? borderColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: backgroundColor,
          shape: CircleBorder(
            side: BorderSide(
              color: borderColor ?? Colors.black.withValues(alpha: 0.08),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionText extends StatelessWidget {
  const _SectionText({required this.body, required this.title});

  final String body;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.34,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FooterActionSection extends StatelessWidget {
  const _FooterActionSection({
    required this.isPrimaryLoading,
    required this.onPrimaryAction,
    required this.primaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
  });

  final bool isPrimaryLoading;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final String primaryActionLabel;
  final String? secondaryActionLabel;

  @override
  Widget build(BuildContext context) {
    final hasSecondaryAction =
        onSecondaryAction != null &&
        secondaryActionLabel != null &&
        secondaryActionLabel!.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: hasSecondaryAction
            ? Row(
                children: [
                  Expanded(
                    child: _BottomActionButton(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      label: secondaryActionLabel!,
                      onTap: onSecondaryAction,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _BottomActionButton(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      label: isPrimaryLoading ? 'Updating' : primaryActionLabel,
                      onTap: onPrimaryAction,
                    ),
                  ),
                ],
              )
            : _BottomActionButton(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                label: isPrimaryLoading ? 'Updating' : primaryActionLabel,
                onTap: onPrimaryAction,
                height: 52,
              ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
    required this.onTap,
    this.border,
    this.height = 52,
  });

  final Color backgroundColor;
  final Border? border;
  final Color foregroundColor;
  final double height;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: onTap == null
              ? backgroundColor.withValues(alpha: 0.48)
              : backgroundColor,
          border: border,
          borderRadius: BorderRadius.circular(30),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkCoverImage extends StatelessWidget {
  const _NetworkCoverImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, _) => const ColoredBox(color: Color(0xFFF4F6F8)),
      errorWidget: (context, _, _) => const ColoredBox(
        color: Color(0xFFF4F6F8),
        child: Icon(Icons.image_not_supported_outlined, color: Colors.black),
      ),
    );
  }
}
