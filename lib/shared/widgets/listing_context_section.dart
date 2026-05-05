import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/geo_discovery/geo_types.dart';

class ListingContextSection extends StatelessWidget {
  const ListingContextSection({
    required this.hostName,
    required this.location,
    super.key,
    this.hostAvatarUrl,
    this.onCallTap,
    this.onMessageTap,
  });

  final String? hostAvatarUrl;
  final String hostName;
  final GeoPoint location;
  final VoidCallback? onCallTap;
  final VoidCallback? onMessageTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingLocationPreviewCard(location: location),
        const SizedBox(height: 12),
        ListingHostCard(
          avatarUrl: hostAvatarUrl,
          hostName: hostName,
          onCallTap: onCallTap,
          onMessageTap: onMessageTap,
        ),
      ],
    );
  }
}

class ListingLocationPreviewCard extends StatelessWidget {
  const ListingLocationPreviewCard({
    required this.location,
    super.key,
    this.height = 126,
    this.zoom = 15,
  });

  final double height;
  final GeoPoint location;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _OsmStaticMap(location: location, zoom: zoom),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x0A000000),
                        Colors.transparent,
                        Color(0x12000000),
                      ],
                    ),
                  ),
                ),
              ),
              const Center(child: _MapPinMarker()),
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'OpenStreetMap',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
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

class ListingHostCard extends StatelessWidget {
  const ListingHostCard({
    required this.hostName,
    super.key,
    this.avatarUrl,
    this.onCallTap,
    this.onMessageTap,
  });

  final String? avatarUrl;
  final String hostName;
  final VoidCallback? onCallTap;
  final VoidCallback? onMessageTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HostAvatar(hostName: hostName, imageUrl: avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Host Information',
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          hostName,
                          maxLines: 2,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF1D9BF0),
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HostActionButton(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    icon: Icons.mode_comment_outlined,
                    isEnabled: onMessageTap != null,
                    onTap: onMessageTap,
                    tooltip: 'Message host',
                  ),
                  const SizedBox(width: 8),
                  _HostActionButton(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    icon: Icons.call_rounded,
                    isEnabled: onCallTap != null,
                    onTap: onCallTap,
                    tooltip: 'Call host',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OsmStaticMap extends StatelessWidget {
  const _OsmStaticMap({required this.location, required this.zoom});

  final GeoPoint location;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final maxLatitude = 85.05112878;
        final clampedLatitude = location.latitude.clamp(
          -maxLatitude,
          maxLatitude,
        );
        final tileCount = 1 << zoom;
        final latitudeRadians = clampedLatitude * math.pi / 180;
        final exactTileX = (location.longitude + 180) / 360 * tileCount;
        final exactTileY =
            (1 -
                math.log(
                      math.tan(latitudeRadians) +
                          (1 / math.cos(latitudeRadians)),
                    ) /
                    math.pi) /
            2 *
            tileCount;
        final originTileX = exactTileX.floor();
        final originTileY = exactTileY.floor();
        final tileExtent = width;
        final centeredPointX = (exactTileX - (originTileX - 1)) * tileExtent;
        final centeredPointY = (exactTileY - (originTileY - 1)) * tileExtent;
        final leftOffset = width / 2 - centeredPointX;
        final topOffset = height / 2 - centeredPointY;

        return ColoredBox(
          color: const Color(0xFFF4F6F8),
          child: Stack(
            children: [
              Positioned(
                left: leftOffset,
                top: topOffset,
                child: SizedBox(
                  width: tileExtent * 3,
                  height: tileExtent * 3,
                  child: Stack(
                    children: [
                      for (var row = 0; row < 3; row++)
                        for (var column = 0; column < 3; column++)
                          Positioned(
                            left: column * tileExtent,
                            top: row * tileExtent,
                            child: SizedBox(
                              width: tileExtent,
                              height: tileExtent,
                              child: CachedNetworkImage(
                                imageUrl: _tileUrl(
                                  x: originTileX + column - 1,
                                  y: originTileY + row - 1,
                                  zoom: zoom,
                                ),
                                fit: BoxFit.cover,
                                placeholder: (context, _) =>
                                    const ColoredBox(color: Color(0xFFEDEFF3)),
                                errorWidget: (context, _, _) =>
                                    const ColoredBox(color: Color(0xFFEDEFF3)),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _tileUrl({required int x, required int y, required int zoom}) {
    final tileCount = 1 << zoom;
    final wrappedX = ((x % tileCount) + tileCount) % tileCount;
    final clampedY = y.clamp(0, tileCount - 1);
    return 'https://tile.openstreetmap.org/$zoom/$wrappedX/$clampedY.png';
  }
}

class _MapPinMarker extends StatelessWidget {
  const _MapPinMarker();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: Icon(
        Icons.location_on_rounded,
        color: Colors.black,
        size: 34,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.hostName, this.imageUrl});

  final String hostName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl?.trim() ?? '';
    if (trimmedUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: trimmedUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (context, _) => _HostInitialAvatar(hostName: hostName),
          errorWidget: (context, _, _) =>
              _HostInitialAvatar(hostName: hostName),
        ),
      );
    }

    return _HostInitialAvatar(hostName: hostName);
  }
}

class _HostInitialAvatar extends StatelessWidget {
  const _HostInitialAvatar({required this.hostName});

  final String hostName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Text(
            _initialsFor(hostName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }

  String _initialsFor(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .toList(growable: false);
    if (parts.isEmpty) return 'H';
    return parts.join();
  }
}

class _HostActionButton extends StatelessWidget {
  const _HostActionButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.isEnabled,
    required this.onTap,
    required this.tooltip,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final bool isEnabled;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEnabled ? backgroundColor : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isEnabled
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Icon(
              icon,
              color: isEnabled ? foregroundColor : const Color(0xFF9CA3AF),
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}
