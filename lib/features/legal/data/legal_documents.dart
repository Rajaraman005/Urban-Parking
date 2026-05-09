import '../domain/legal_document.dart';

const _contactBlock =
    'For privacy, grievance, safety, or legal notices, contact Lotzi at grievance@lotzi.in or legal@lotzi.in. We may verify your identity before acting on account, privacy, payout, or listing requests.';

const privacyPolicy = LegalDocument(
  title: 'Privacy Policy',
  subtitle: 'How Lotzi collects, uses, protects, and shares personal data.',
  effectiveDate: 'Effective 1 May 2026',
  reviewNote:
      'Built for Indian users and aligned to the Digital Personal Data Protection Act, 2023, IT Rules, 2021, and platform marketplace practices. Final launch text should be reviewed by counsel.',
  sections: [
    LegalSection(
      title: '1. Scope',
      body: [
        'This Privacy Policy applies to Lotzi mobile apps, websites, support channels, booking flows, host listing flows, and related services.',
        'Lotzi acts as a digital marketplace for parking spaces, mobility rentals, and vehicle services. We process personal data to operate, secure, improve, and support the platform.',
      ],
    ),
    LegalSection(
      title: '2. Personal data we collect',
      body: [
        'Account data includes name, mobile number, email address, login credentials, profile preferences, support history, and consent records.',
        'Booking and listing data includes parking location, availability, pricing, photos, vehicle details, booking dates, check-in activity, cancellations, disputes, ratings, and reviews.',
        'Location data is used only when you allow it for search, nearby discovery, route context, fraud prevention, and booking support.',
      ],
    ),
    LegalSection(
      title: '3. Why we use data',
      body: [
        'We use data to create accounts, verify users, show nearby spaces, process bookings, support host payouts, provide customer support, and send service notices.',
        'We also use data to prevent fraud, abuse, unsafe activity, unauthorized access, duplicate listings, payment misuse, and Terms violations.',
      ],
    ),
    LegalSection(
      title: '4. Location privacy',
      body: [
        'Precise coordinates are sent only for active discovery requests. Logs and telemetry use rounded geocells and never retain a per-user location trail.',
        'Cached nearby results expire quickly and are cleared on logout or account deletion requests where applicable.',
      ],
    ),
    LegalSection(
      title: '5. User rights and grievance redressal',
      body: [
        'Subject to applicable law, you may request access, correction, deletion, grievance redressal, and withdrawal of consent.',
        _contactBlock,
      ],
    ),
  ],
);

const termsOfUse = LegalDocument(
  title: 'Terms of Use',
  subtitle:
      'Rules for using Lotzi as a guest, host, renter, or service customer.',
  effectiveDate: 'Effective 1 May 2026',
  reviewNote:
      'Designed for an India-first parking marketplace and aligned to consumer, intermediary, payment, and platform safety expectations. Final launch text should be reviewed by counsel.',
  sections: [
    LegalSection(
      title: '1. Acceptance',
      body: [
        'By creating an account, browsing, listing, booking, renting, paying, reviewing, or contacting support through Lotzi, you agree to these Terms of Use and our Privacy Policy.',
      ],
    ),
    LegalSection(
      title: '2. What Lotzi provides',
      body: [
        'Lotzi is a technology marketplace that helps users discover, list, book, and manage parking spaces, mobility rentals, and vehicle-related services.',
        'Unless expressly stated, Lotzi does not own, operate, control, inspect, insure, or manage listed parking spaces, vehicles, or third-party services.',
      ],
    ),
    LegalSection(
      title: '3. Host and guest responsibilities',
      body: [
        'Hosts must have the legal right, permission, society approval, lease permission, or owner authorization needed to list a parking space.',
        'Guests must use spaces only for lawful parking, follow time limits and access instructions, avoid obstruction or nuisance, and leave spaces in the condition received.',
      ],
    ),
    LegalSection(
      title: '4. Bookings, payments, and safety',
      body: [
        'Prices, taxes, fees, cancellation terms, payout timing, and refund eligibility are shown in the app before confirmation or in booking details.',
        'Lotzi is not a valet, bailee, insurer, garage operator, or security provider unless a specific service says otherwise in writing.',
      ],
    ),
    LegalSection(title: '5. Grievances', body: [_contactBlock]),
  ],
);
