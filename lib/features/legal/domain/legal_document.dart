class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final List<String> body;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.subtitle,
    required this.effectiveDate,
    required this.reviewNote,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final String effectiveDate;
  final String reviewNote;
  final List<LegalSection> sections;
}
