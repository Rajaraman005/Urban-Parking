import 'package:flutter/material.dart';

import 'app_screen.dart';

class TabPlaceholderScreen extends StatelessWidget {
  const TabPlaceholderScreen({
    required this.icon,
    required this.sectionLabel,
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.footerTitle,
    required this.footerBody,
    super.key,
  });

  final IconData icon;
  final String sectionLabel;
  final String title;
  final String subtitle;
  final List<String> highlights;
  final String footerTitle;
  final String footerBody;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScreen(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        sectionLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in highlights) Chip(label: Text(item)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    footerTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    footerBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
