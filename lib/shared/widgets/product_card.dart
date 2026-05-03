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
  final String subtitle;
  final String title;

  static const _radius = 8.0;
  static const _inkColor = Color(0xFF0B0B0C);
  static const _frameColor = Color(0xFFE9E9EB);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: _frameColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                              height: 1.1,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (priceText != null) ...[
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 118),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                priceText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: _inkColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _inkColor.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final stat in stats) _ProductCardStatChip(stat),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ProductCard._frameColor,
          borderRadius: BorderRadius.circular(ProductCard._radius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: _optimizedImageUrl(imageUrl),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  fadeInDuration: const Duration(milliseconds: 180),
                  fadeOutDuration: const Duration(milliseconds: 90),
                  placeholder: (context, _) => ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (context, _, _) => ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Text(
                          badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ProductCard._inkColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      if (onFavoritePressed != null) ...[
                        _ProductCardIconButton(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          foregroundColor: favoriteSelected
                              ? const Color(0xFFE11D48)
                              : ProductCard._inkColor,
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
                          backgroundColor: ProductCard._inkColor,
                          foregroundColor: Colors.white,
                          icon: Icons.arrow_outward_rounded,
                          semanticLabel: 'Open details',
                          onPressed: onOpenPressed!,
                        ),
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

  String _optimizedImageUrl(String url) {
    if (url.contains('images.unsplash.com') && !url.contains('?')) {
      return '$url?auto=format&fit=crop&w=1000&q=82';
    }
    return url;
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
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: foregroundColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ProductCardStatChip extends StatelessWidget {
  const _ProductCardStatChip(this.stat);

  final ProductCardStat stat;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stat.icon != null) ...[
              Icon(stat.icon, color: ProductCard._inkColor, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ProductCard._inkColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
