export interface LegalSection {
  title: string;
  body: string[];
}

export interface LegalDocument {
  title: string;
  subtitle: string;
  effectiveDate: string;
  reviewNote: string;
  sections: LegalSection[];
}

const contactBlock =
  "For privacy, grievance, safety, or legal notices, contact Urban Parking at grievance@urbanparking.app or legal@urbanparking.app. We may verify your identity before acting on account, privacy, payout, or listing requests.";

export const privacyPolicy: LegalDocument = {
  title: "Privacy Policy",
  subtitle: "How Urban Parking collects, uses, protects, and shares personal data.",
  effectiveDate: "Effective 1 May 2026",
  reviewNote:
    "Built for Indian users and aligned to the Digital Personal Data Protection Act, 2023, IT Rules, 2021, and platform marketplace practices. Final launch text should be reviewed by counsel.",
  sections: [
    {
      title: "1. Scope",
      body: [
        "This Privacy Policy applies to Urban Parking mobile apps, websites, support channels, booking flows, host listing flows, and related services.",
        "Urban Parking acts as a digital marketplace for parking spaces, mobility rentals, and vehicle services. We process personal data to operate, secure, improve, and support the platform."
      ]
    },
    {
      title: "2. Personal data we collect",
      body: [
        "Account data: name, mobile number, email address, login credentials, profile preferences, support history, and consent records.",
        "Booking and listing data: parking location, availability, pricing, photos, vehicle details, booking dates, check-in activity, cancellations, disputes, ratings, and reviews.",
        "Location data: approximate or precise location when you allow it, used for search, nearby discovery, route context, fraud prevention, and booking support.",
        "Payment data: transaction identifiers, payout status, refunds, invoices, tax metadata, and limited payment status received from payment partners. We do not store full card numbers or UPI credentials.",
        "Device and usage data: device identifiers, app version, IP address, crash logs, diagnostics, feature usage, fraud signals, and security events."
      ]
    },
    {
      title: "3. Why we use data",
      body: [
        "To create accounts, verify users, show nearby spaces, process bookings, support host payouts, provide customer support, and send service notices.",
        "To prevent fraud, abuse, unsafe activity, unauthorized access, duplicate listings, payment misuse, and violations of our Terms of Use.",
        "To personalize search results, improve pricing and availability tools, measure app performance, maintain records required by law, and respond to lawful requests.",
        "Where required, we rely on consent. You may withdraw consent through app settings or by contacting us, but some services may stop working if the data is necessary for that service."
      ]
    },
    {
      title: "4. Sharing and disclosure",
      body: [
        "We share booking details between guests and hosts only as needed to complete a booking, resolve support issues, or enforce platform rules.",
        "We use service providers for cloud hosting, analytics, maps, notifications, payment processing, fraud prevention, customer support, and communications.",
        "We may share data with law enforcement, courts, regulators, government authorities, insurers, payment partners, or professional advisers when required by law or necessary to protect users and the platform.",
        "We do not sell personal data. We do not permit third parties to use personal data for their independent advertising unless you have consented or the law permits it."
      ]
    },
    {
      title: "5. User rights",
      body: [
        "Subject to applicable law, you may request access to information about your personal data, correction of inaccurate data, completion of incomplete data, deletion of data, grievance redressal, and withdrawal of consent.",
        "You may also nominate another person to exercise your rights in the event of death or incapacity where applicable law recognizes that right.",
        "We may retain limited records after deletion requests where needed for fraud prevention, tax, accounting, legal claims, safety investigations, or statutory obligations."
      ]
    },
    {
      title: "6. Children and sensitive use",
      body: [
        "Urban Parking is not intended for children. Users must be legally capable of entering into contracts for bookings, payments, and listings.",
        "We do not knowingly process children’s personal data for behavioral advertising or tracking. If we learn that a child’s data was provided without valid authority, we will restrict or delete it as appropriate."
      ]
    },
    {
      title: "7. Security and retention",
      body: [
        "We use technical and organizational safeguards such as access controls, encryption in transit, monitoring, least-privilege permissions, audit logging, and incident response processes.",
        "No digital service is completely risk-free. If a personal data breach requires notice under applicable law, we will notify affected users and authorities as required.",
        "We keep personal data only as long as needed for the purposes described in this Policy, unless a longer period is required for legal, tax, accounting, safety, fraud, or dispute reasons."
      ]
    },
    {
      title: "8. Cross-border processing",
      body: [
        "Urban Parking may use infrastructure and vendors in India or other jurisdictions. Where data is transferred outside India, we apply contractual, technical, and organizational safeguards and follow applicable restrictions.",
        "Payment, map, analytics, and notification providers may process data under their own security and compliance programs."
      ]
    },
    {
      title: "9. Grievance redressal",
      body: [
        contactBlock,
        "We aim to acknowledge privacy or grievance requests within a reasonable time and resolve them according to applicable law, platform safety needs, and the complexity of the request."
      ]
    },
    {
      title: "10. Updates",
      body: [
        "We may update this Policy as our services, laws, or practices change. Material changes will be communicated in the app or through another reasonable method before they take effect where required."
      ]
    }
  ]
};

export const termsOfUse: LegalDocument = {
  title: "Terms of Use",
  subtitle: "Rules for using Urban Parking as a guest, host, renter, or service customer.",
  effectiveDate: "Effective 1 May 2026",
  reviewNote:
    "Designed for an India-first parking marketplace and aligned to consumer, intermediary, payment, and platform safety expectations. Final launch text should be reviewed by counsel.",
  sections: [
    {
      title: "1. Acceptance",
      body: [
        "By creating an account, browsing, listing, booking, renting, paying, reviewing, or contacting support through Urban Parking, you agree to these Terms of Use and our Privacy Policy.",
        "If you use Urban Parking for a company, housing society, fleet, or business, you confirm that you are authorized to bind that organization."
      ]
    },
    {
      title: "2. What Urban Parking provides",
      body: [
        "Urban Parking is a technology marketplace that helps users discover, list, book, and manage parking spaces, mobility rentals, and vehicle-related services.",
        "Unless expressly stated, Urban Parking does not own, operate, control, inspect, insure, or manage listed parking spaces, vehicles, or third-party services. Hosts and service providers are responsible for their listings and services."
      ]
    },
    {
      title: "3. Eligibility and accounts",
      body: [
        "You must be legally competent to contract, provide accurate account information, keep credentials secure, and promptly update information that affects bookings, payouts, safety, or support.",
        "We may require identity, vehicle, ownership, authorization, tax, or payout verification before allowing certain listings, bookings, payouts, refunds, or high-risk activity."
      ]
    },
    {
      title: "4. Host responsibilities",
      body: [
        "Hosts must have the legal right, permission, society approval, lease permission, or owner authorization needed to list a parking space.",
        "Hosts must describe spaces accurately, disclose restrictions, maintain safe access, honor confirmed bookings, keep pricing and availability current, and comply with local rules, building rules, tax obligations, and applicable law.",
        "Hosts are responsible for disputes caused by inaccurate descriptions, unsafe spaces, unauthorized listings, blocked access, or failure to honor bookings."
      ]
    },
    {
      title: "5. Guest responsibilities",
      body: [
        "Guests must use spaces only for lawful parking, follow time limits and access instructions, avoid obstruction or nuisance, and leave spaces in the condition received.",
        "Guests are responsible for vehicle condition, valuables, traffic fines, towing, damage caused by them, overstays, and misuse of a listed space."
      ]
    },
    {
      title: "6. Bookings, payments, cancellations",
      body: [
        "Prices, taxes, fees, cancellation terms, payout timing, and refund eligibility are shown in the app before confirmation or in the booking details.",
        "Payments may be processed by third-party payment aggregators, gateways, banks, or UPI providers. Urban Parking does not store full card, UPI PIN, or net-banking credentials.",
        "Approved refunds are returned through the original payment method or another permitted method, subject to banking timelines, payment partner rules, fraud checks, and applicable law."
      ]
    },
    {
      title: "7. Prohibited conduct",
      body: [
        "You must not post false listings, use another person’s property without authority, bypass platform payments, harass users, damage property, misuse location data, scrape the app, reverse engineer systems, or upload unlawful content.",
        "You must not upload content that infringes rights, invades privacy, is obscene, harmful to children, defamatory, discriminatory, misleading, fraudulent, or otherwise unlawful."
      ]
    },
    {
      title: "8. Safety, damage, and insurance",
      body: [
        "Urban Parking is not a valet, bailee, insurer, garage operator, or security provider unless a specific service says otherwise in writing.",
        "Users should maintain appropriate vehicle insurance, property permissions, and personal safety practices. Any damage, theft, injury, towing, or enforcement issue may require cooperation between users, authorities, insurers, and support."
      ]
    },
    {
      title: "9. Content, reviews, and moderation",
      body: [
        "You grant Urban Parking a license to host, display, use, translate, and process content you submit for operating, improving, promoting, and securing the platform.",
        "We may remove or restrict listings, reviews, messages, accounts, or content that violates these Terms, law, safety standards, user trust, or platform integrity."
      ]
    },
    {
      title: "10. Suspension and enforcement",
      body: [
        "We may warn, restrict, suspend, terminate, delist, block payouts, cancel bookings, or hold funds where needed for safety, fraud prevention, legal compliance, chargebacks, disputes, or Terms violations.",
        "Where required, users may raise grievances about platform decisions through the grievance contact."
      ]
    },
    {
      title: "11. Disclaimers and liability",
      body: [
        "Urban Parking provides the platform on an “as is” and “as available” basis. We do not guarantee uninterrupted access, perfect availability, listing accuracy, user conduct, parking suitability, or third-party service quality.",
        "To the maximum extent permitted by law, Urban Parking will not be liable for indirect, incidental, special, punitive, or consequential losses, loss of profit, loss of data, vehicle damage, theft, personal injury, or third-party acts not caused by our proven fault.",
        "Nothing in these Terms limits rights that cannot be limited under applicable consumer law."
      ]
    },
    {
      title: "12. Governing law and grievances",
      body: [
        "These Terms are governed by the laws of India. Disputes are subject to courts or forums with competent jurisdiction under applicable law.",
        contactBlock
      ]
    },
    {
      title: "13. Changes",
      body: [
        "We may update these Terms as services, risks, laws, or business models change. Continued use after an update means you accept the updated Terms, unless law requires a different process."
      ]
    }
  ]
};
