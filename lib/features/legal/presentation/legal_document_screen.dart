import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/app_screen.dart';
import '../domain/legal_document.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  static const _backgroundColor = Color(0xFFFFFFFF);
  static const _inkColor = Color(0xFF0B0B0C);
  static const _bodyColor = Color(0xFF34343A);
  static const _mutedColor = Color(0xFF565656);
  static const _softSurface = Color(0xFFF7F7F8);
  static const _borderColor = Color(0xFFE1E2E5);
  static const _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: _backgroundColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: _backgroundColor,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: AppScreen(
        backgroundColor: _backgroundColor,
        safeAreaBackgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          foregroundColor: _inkColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          title: Text(document.title, style: _topBarTitleStyle(theme)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 34),
          children: [
            _DocumentHeader(document: document),
            const SizedBox(height: 18),
            _ReviewNoteCard(text: document.reviewNote),
            const SizedBox(height: 26),
            for (var index = 0; index < document.sections.length; index++) ...[
              _LegalSectionBlock(section: document.sections[index]),
              if (index < document.sections.length - 1) const _SectionDivider(),
            ],
          ],
        ),
      ),
    );
  }

  static TextStyle _topBarTitleStyle(ThemeData theme) {
    return (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: _inkColor,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: 0,
    );
  }

  static TextStyle titleStyle(ThemeData theme) {
    return (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
      color: _inkColor,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: 0,
    );
  }

  static TextStyle subtitleStyle(ThemeData theme) {
    return (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: _bodyColor,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.38,
      letterSpacing: 0,
    );
  }

  static TextStyle metaStyle(ThemeData theme) {
    return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: _mutedColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  static TextStyle sectionTitleStyle(ThemeData theme) {
    return (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      color: _inkColor,
      fontSize: 21,
      fontWeight: FontWeight.w800,
      height: 1.18,
      letterSpacing: 0,
    );
  }

  static TextStyle bodyStyle(ThemeData theme) {
    return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: _bodyColor,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      height: 1.58,
      letterSpacing: 0,
    );
  }

  static TextStyle noteStyle(ThemeData theme) {
    return (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: _bodyColor,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      height: 1.48,
      letterSpacing: 0,
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(document.title, style: LegalDocumentScreen.titleStyle(theme)),
        const SizedBox(height: 10),
        Text(
          document.subtitle,
          style: LegalDocumentScreen.subtitleStyle(theme),
        ),
        const SizedBox(height: 14),
        _EffectiveDatePill(text: document.effectiveDate),
      ],
    );
  }
}

class _EffectiveDatePill extends StatelessWidget {
  const _EffectiveDatePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LegalDocumentScreen._softSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LegalDocumentScreen._borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          text,
          style: LegalDocumentScreen.metaStyle(Theme.of(context)),
        ),
      ),
    );
  }
}

class _ReviewNoteCard extends StatelessWidget {
  const _ReviewNoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LegalDocumentScreen._softSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LegalDocumentScreen._borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NoticeIcon(),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: LegalDocumentScreen.noteStyle(Theme.of(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LegalDocumentScreen._borderColor),
      ),
      child: const SizedBox(
        width: 30,
        height: 30,
        child: Icon(
          Icons.verified_user_outlined,
          color: LegalDocumentScreen._inkColor,
          size: 16,
        ),
      ),
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: LegalDocumentScreen.sectionTitleStyle(theme),
        ),
        const SizedBox(height: 11),
        for (var index = 0; index < section.body.length; index++) ...[
          Text(
            section.body[index],
            style: LegalDocumentScreen.bodyStyle(theme),
          ),
          if (index < section.body.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 23),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}
