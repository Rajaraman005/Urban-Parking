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
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenPressed;
  final VoidCallback? onTap;
  final String? priceText;
  final List<ProductCardStat> stats;
  final bool statsEvenlySpaced;
  final String subtitle;
  final String title;

  static const _radius = 8.0;
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
                  imageUrl: imageUrl,
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
}

class _ProductCardImage extends StatelessWidget {
  const _ProductCardImage({
    required this.favoriteSelected,
    required this.height,
    required this.imageUrl,
    this.badge,
    this.onFavoritePressed,
    this.onOpenPressed,
  });

  final String? badge;
  final bool favoriteSelected;
  final double height;
  final String imageUrl;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenPressed;

  @override
  Widget build(BuildContext context) {
    final bottomShadeOpacity = badge == null ? 0.18 : 0.62;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
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
          ),
          DecoratedBox(
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.08),
              child: const SizedBox(height: 1),
            ),
          ),
          if (badge != null)
            Positioned(
              left: 12,
              right: 72,
              bottom: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ProductCardBadge(badge!),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                if (onFavoritePressed != null) ...[
                  _ProductCardIconButton(
                    backgroundColor: Colors.white.withValues(alpha: 0.94),
                    foregroundColor: ProductCard._inkColor,
                    icon: favoriteSelected
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    semanticLabel: 'Save',
                    onPressed: onFavoritePressed!,
                  ),
                  const SizedBox(width: 8),
                ],
                if (onOpenPressed != null)
                  _ProductCardIconButton(
                    backgroundColor: Colors.white.withValues(alpha: 0.94),
                    foregroundColor: ProductCard._inkColor,
                    icon: Icons.arrow_outward_rounded,
                    semanticLabel: 'Open details',
                    onPressed: onOpenPressed!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _optimizedImageUrl(String url) {
    if (url.contains('images.unsplash.com') && !url.contains('?')) {
      return '$url?auto=format&fit=crop&w=1000&q=84';
    }
    return url;
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
