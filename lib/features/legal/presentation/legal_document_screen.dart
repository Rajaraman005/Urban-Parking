import 'package:flutter/material.dart';

import '../../../shared/widgets/app_screen.dart';
import '../domain/legal_document.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScreen(
      appBar: AppBar(title: Text(document.title)),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 12),
          Text(
            document.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            document.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            document.effectiveDate,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(document.reviewNote),
            ),
          ),
          const SizedBox(height: 18),
          for (final section in document.sections) ...[
            Text(
              section.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final paragraph in section.body)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(paragraph, style: const TextStyle(height: 1.45)),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
