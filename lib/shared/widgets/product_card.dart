import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductCardStat {
  const ProductCardStat({required this.label, this.icon});

  final IconData? icon;
  final String label;
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    super.key,
    this.badge,
    this.favoriteSelected = false,
    this.imageHeight = 156,
    this.imageUrls = const [],
    this.onFavoritePressed,
    this.onOpenPressed,
    this.onTap,
    this.priceText,
    this.stats = const [],
    this.statsEvenlySpaced = false,
  });

  final String? badge;
  final bool favoriteSelected;
  final double imageHeight;
  final String imageUrl;
  final List<String> imageUrls;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenPressed;
  final VoidCallback? onTap;
  final String? priceText;
  final List<ProductCardStat> stats;
  final bool statsEvenlySpaced;
  final String subtitle;
  final String title;

  static const _radius = 8.0;
  static const _imageRadius = 10.0;
  static const _inkColor = Color(0xFF0B0B0C);
  static const _mutedColor = Color(0xFF686872);
  static const _softSurface = Color(0xFFF7F7F8);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title, $subtitle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: _inkColor.withValues(alpha: 0.06),
            highlightColor: _inkColor.withValues(alpha: 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductCardImage(
                  badge: badge,
                  favoriteSelected: favoriteSelected,
                  height: imageHeight,
                  imageUrls: _normalizedImageUrls(imageUrl, imageUrls),
                  onFavoritePressed: onFavoritePressed,
                  onOpenPressed: onOpenPressed,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _inkColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (priceText != null) ...[
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 126),
                              child: _ProductCardPrice(priceText!),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                          letterSpacing: 0,
                        ),
                      ),
                      if (stats.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ProductCardStatsRow(
                          evenlySpaced: statsEvenlySpaced,
                          stats: stats,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<String> _normalizedImageUrls(
    String primaryUrl,
    List<String> extraUrls,
  ) {
    final urls = <String>{};

    void addUrl(String? rawUrl) {
      final url = rawUrl?.trim();
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }

    for (final url in extraUrls) {
      addUrl(url);
    }
    addUrl(primaryUrl);

    return urls.toList(growable: false);
  }
}

class _ProductCardImage extends StatefulWidget {
  const _ProductCardImage({
    required this.favoriteSelected,
    required this.height,
    required this.imageUrls,
    this.badge,
    this.onFavoritePressed,
    this.onOpenPressed,
  });

  final String? badge;
  final bool favoriteSelected;
  final double height;
  final List<String> imageUrls;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenPressed;

  @override
  State<_ProductCardImage> createState() => _ProductCardImageState();
}

class _ProductCardImageState extends State<_ProductCardImage> {
  late final PageController _pageController;
  late String _imageSignature;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _imageSignature = _signatureFor(widget.imageUrls);
  }

  @override
  void didUpdateWidget(covariant _ProductCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextSignature = _signatureFor(widget.imageUrls);
    if (nextSignature == _imageSignature) {
      if (_pageIndex >= widget.imageUrls.length) {
        _pageIndex = widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1;
      }
      return;
    }

    _imageSignature = nextSignature;
    _pageIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.imageUrls.isEmpty
        ? const <String>['']
        : widget.imageUrls;
    final bottomShadeOpacity = widget.badge == null ? 0.18 : 0.62;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: ProductCard._softSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProductCard._imageRadius),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrls.length == 1)
                _ProductCardNetworkImage(imageUrl: imageUrls.first)
              else
                PageView.builder(
                  controller: _pageController,
                  itemCount: imageUrls.length,
                  onPageChanged: (index) => setState(() {
                    _pageIndex = index;
                  }),
                  itemBuilder: (context, index) {
                    return _ProductCardNetworkImage(imageUrl: imageUrls[index]);
                  },
                ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.06),
                        Colors.transparent,
                        Colors.black.withValues(alpha: bottomShadeOpacity),
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
              ),
              if (widget.badge != null)
                Positioned(
                  left: 12,
                  right: 72,
                  bottom: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IgnorePointer(
                      child: _ProductCardBadge(widget.badge!),
                    ),
                  ),
                ),
              if (imageUrls.length > 1)
                Positioned(
                  left: widget.badge == null ? 0 : null,
                  right: widget.badge == null ? 0 : 12,
                  bottom: 10,
                  child: Align(
                    alignment: widget.badge == null
                        ? Alignment.bottomCenter
                        : Alignment.bottomRight,
                    child: IgnorePointer(
                      child: _ProductCardCarouselDots(
                        activeIndex: _pageIndex,
                        count: imageUrls.length,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    if (widget.onFavoritePressed != null) ...[
                      _ProductCardIconButton(
                        backgroundColor: Colors.white.withValues(alpha: 0.94),
                        foregroundColor: ProductCard._inkColor,
                        icon: widget.favoriteSelected
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        semanticLabel: 'Save',
                        onPressed: widget.onFavoritePressed!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.onOpenPressed != null)
                      _ProductCardIconButton(
                        backgroundColor: Colors.white.withValues(alpha: 0.94),
                        foregroundColor: ProductCard._inkColor,
                        icon: Icons.arrow_outward_rounded,
                        semanticLabel: 'Open details',
                        onPressed: widget.onOpenPressed!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _signatureFor(List<String> urls) => urls.join('\n');
}

class _ProductCardNetworkImage extends StatelessWidget {
  const _ProductCardNetworkImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const ColoredBox(
        color: ProductCard._softSurface,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: ProductCard._mutedColor,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: _optimizedImageUrl(imageUrl),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 90),
      placeholder: (context, _) =>
          const ColoredBox(color: ProductCard._softSurface),
      errorWidget: (context, _, _) => const ColoredBox(
        color: ProductCard._softSurface,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: ProductCard._mutedColor,
          ),
        ),
      ),
    );
  }

  static String _optimizedImageUrl(String url) {
    if (url.contains('images.unsplash.com') && !url.contains('?')) {
      return '$url?auto=format&fit=crop&w=1000&q=84';
    }
    return url;
  }
}

class _ProductCardCarouselDots extends StatelessWidget {
  const _ProductCardCarouselDots({
    required this.activeIndex,
    required this.count,
  });

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo ${activeIndex + 1} of $count',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < count; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: index == activeIndex ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: index == activeIndex ? 0.96 : 0.52,
                    ),
                    borderRadius: BorderRadius.circular(999),
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

class _ProductCardStatsRow extends StatelessWidget {
  const _ProductCardStatsRow({required this.evenlySpaced, required this.stats});

  final bool evenlySpaced;
  final List<ProductCardStat> stats;

  @override
  Widget build(BuildContext context) {
    if (!evenlySpaced) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final stat in stats) _ProductCardStatChip(stat)],
      );
    }

    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _ProductCardStatChip(stats[index], expanded: true)),
        ],
      ],
    );
  }
}

class _ProductCardBadge extends StatelessWidget {
  const _ProductCardBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ProductCard._inkColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ProductCardPrice extends StatelessWidget {
  const _ProductCardPrice(this.priceText);

  final String priceText;

  @override
  Widget build(BuildContext context) {
    final slashIndex = priceText.indexOf('/');
    if (slashIndex <= 0) {
      return Text(
        priceText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: ProductCard._inkColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: 0,
        ),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      text: TextSpan(
        children: [
          TextSpan(
            text: priceText.substring(0, slashIndex),
            style: const TextStyle(
              color: ProductCard._inkColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
          TextSpan(
            text: priceText.substring(slashIndex),
            style: const TextStyle(
              color: ProductCard._inkColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCardIconButton extends StatelessWidget {
  const _ProductCardIconButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: foregroundColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCardStatChip extends StatelessWidget {
  const _ProductCardStatChip(this.stat, {this.expanded = false});

  final bool expanded;
  final ProductCardStat stat;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      stat.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ProductCard._inkColor,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: expanded
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (stat.icon != null) ...[
              Icon(stat.icon, color: ProductCard._inkColor, size: 13),
              const SizedBox(width: 6),
            ],
            if (expanded) Flexible(child: label) else label,
          ],
        ),
      ),
    );
  }
}
