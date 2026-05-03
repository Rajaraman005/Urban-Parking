import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetworkImageTile extends StatelessWidget {
  const NetworkImageTile({
    required this.url,
    super.key,
    this.height = 150,
    this.borderRadius = 8,
  });

  final String url;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: '$url?auto=format&fit=crop&w=900&q=80',
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}
