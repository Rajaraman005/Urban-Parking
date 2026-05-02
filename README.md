# Urban Parking

Production-grade Expo SDK 54 + React Native foundation for a peer-to-peer parking marketplace.

## Stack

- Expo SDK 54, React Native 0.81, TypeScript strict mode.
- Zustand for lean, feature-scoped auth and marketplace state.
- React Navigation native stack + bottom tabs.
- Supabase Auth, Postgres, RLS, SecureStore-backed session persistence.
- Native Google token acquisition with Firebase/Google credentials, bridged into Supabase sessions.
- Resend signup OTP through Supabase Edge Functions.
- Signed Cloudinary uploads through Supabase Edge Functions for host listing photos.
- React Hook Form + Zod for auth validation.

## Auth Structure

```txt
src/features/auth
  components/
    AuthBottomSheet.tsx
    AuthButtons.tsx
    AuthInputField.tsx
    AuthFormLayout.tsx
    GoogleLogo.tsx
  hooks/
    useAuthSession.ts
    useVerifiedEmailGuard.ts
  schemas/
    authSchemas.ts
  screens/
    AuthScreen.tsx
    EmailOtpScreen.tsx
    PasswordResetRequestScreen.tsx
    PasswordUpdateScreen.tsx
  services/
    authErrors.ts
    authService.ts
    deviceFingerprint.ts
    googleNativeAuth.ts
  store/
    authStore.ts
  types/
    auth.types.ts

src/lib/supabase
  client.ts
  database.types.ts
  secureStorage.ts

supabase/migrations
  202605010001_auth_profiles.sql
  202605010002_signup_email_otps.sql
  202605010003_user_setup_and_parking_spaces.sql

supabase/functions
  request-signup-otp/
  verify-signup-otp/
  create-cloudinary-upload-signature/
  cleanup-cloudinary-orphans/
```

## Post-Login Setup

Authenticated users route through `src/features/userSetup` before entering `MainTabs` unless `profiles.onboarding_completed_at` is set.

- Parker path: intent -> contact profile -> Home.
- Host path: intent -> profile -> listing basics -> pricing/size -> photos -> review -> `pending_review`.
- Host drafts are persisted in `parking_spaces.status = 'draft'` and restored from `profiles.setup_draft_id`.
- Listing approval is gated. Client code cannot make a listing `active`; submission uses `submit_parking_space_for_review`.

## Environment

Copy `.env.example` to `.env` and set:

```bash
EXPO_PUBLIC_API_BASE_URL=https://api.urbanparking.local/v1
EXPO_PUBLIC_APP_ENV=development
EXPO_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-public-anon-key
EXPO_PUBLIC_AUTH_REDIRECT_SCHEME=urbanparking
EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID=your-google-ios-client-id.apps.googleusercontent.com
EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME=your-cloudinary-cloud-name
EXPO_PUBLIC_CLOUDINARY_UPLOAD_FOLDER=urban-parking/listing-photos
```

Never commit `.env`, `RESEND_API_KEY`, `OTP_PEPPER`, Cloudinary API secrets, or any Supabase service role key.

## Supabase Setup

1. Run all SQL files in `supabase/migrations`.
2. Enable Email provider and Google provider in Supabase Auth.
3. Disable Supabase's default signup confirmation email when using the custom Resend OTP flow.
4. Add native and web redirect URLs for the configured scheme, for example `urbanparking://auth/callback`.
5. Configure Google native sign-in for EAS builds with Firebase/Google client IDs.
6. Set Edge Function secrets:

```bash
npx supabase secrets set RESEND_API_KEY=your-resend-key
npx supabase secrets set RESEND_FROM_EMAIL="Urban Parking <verify@yourdomain.com>"
npx supabase secrets set OTP_PEPPER=long-random-server-only-secret
npx supabase secrets set CLOUDINARY_CLOUD_NAME=your-cloud-name
npx supabase secrets set CLOUDINARY_API_KEY=your-cloudinary-api-key
npx supabase secrets set CLOUDINARY_API_SECRET=your-cloudinary-api-secret
npx supabase secrets set CLOUDINARY_UPLOAD_FOLDER=urban-parking/listing-photos
npx supabase secrets set CLOUDINARY_CLEANUP_SECRET=long-random-cleanup-secret
```

7. Deploy:

```bash
npx supabase functions deploy request-signup-otp
npx supabase functions deploy verify-signup-otp
npx supabase functions deploy create-cloudinary-upload-signature
npx supabase functions deploy cleanup-cloudinary-orphans
```

Use short-lived access tokens in production and configure Supabase Auth rate limits. Native Google sign-in requires an EAS development or production build; it is not an Expo Go flow.

## Run

```bash
npm install
npm run typecheck
npm run lint
npx expo install --check
npm start -- --clear
```

## Production Checks

```bash
npx expo export --platform android --output-dir .expo-export-check
```

Remove `.expo-export-check` after the bundle check if you do not need the generated output.
