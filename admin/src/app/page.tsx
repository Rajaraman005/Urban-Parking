import Link from "next/link";

export default function LandingPage() {
  return (
    <main className="flex min-h-screen items-center justify-center overflow-hidden bg-[#08090a] px-5 py-8 text-white">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_-10%,rgba(116,255,43,0.18),transparent_32rem),linear-gradient(180deg,#101214_0%,#08090a_56%)]"
      />
      <section aria-label="Flowaux coming soon" className="relative flex w-full max-w-[680px] flex-col items-center gap-6 text-center">
        <div className="inline-flex items-center gap-3.5" aria-label="Flowaux">
          <div className="grid h-16 w-16 place-items-center rounded-[18px] bg-[#74ff2b] shadow-[0_18px_44px_rgba(116,255,43,0.22)]">
            <svg aria-hidden="true" width="38" height="38" viewBox="0 0 38 38" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M9 29V8.5h12.1c5.2 0 8.9 3.1 8.9 7.8 0 4.8-3.7 7.9-8.9 7.9h-5.4V29H9Z" fill="#070809" />
              <path d="M15.7 18.5h4.9c1.9 0 3.1-.9 3.1-2.2s-1.2-2.1-3.1-2.1h-4.9v4.3Z" fill="#74FF2B" />
              <path d="M16 29c4.7 0 8.5-3.8 8.5-8.5H16V29Z" fill="#070809" />
            </svg>
          </div>
          <div className="text-[clamp(34px,7vw,58px)] font-black leading-none">
            Flowaux<span className="ml-2 align-[0.06em] text-[0.72em] text-[#ef4444]">&hearts;</span>
          </div>
        </div>

        <div className="w-full max-w-[580px] rounded-3xl border border-white/15 bg-white/[0.06] p-[clamp(26px,5vw,46px)] shadow-[0_24px_80px_rgba(0,0,0,0.34)]">
          <p className="mb-3.5 text-[13px] font-black uppercase text-[#74ff2b]">Launching soon</p>
          <h1 className="m-0 text-[clamp(36px,8vw,72px)] font-black leading-[0.96]">Coming soon</h1>
          <p className="mx-auto mt-5 max-w-[460px] text-[clamp(15px,2.5vw,18px)] font-semibold leading-[1.55] text-[#a3aab8]">
            We are building a location-first marketplace for parking, rentals, and services.
          </p>
          <p className="mt-7 border-t border-white/15 pt-5 text-sm font-extrabold text-[#d8dde7]">flowaux.in</p>
        </div>

        <Link className="text-xs font-semibold text-white/45 transition hover:text-white/75" href="/login">
          Admin sign in
        </Link>
      </section>
    </main>
  );
}
