import Link from "next/link";

export const dynamic = "force-dynamic";

export default function LandingPage() {
  return (
    <main className="flex min-h-screen items-center justify-center overflow-hidden bg-[#08090a] px-5 py-8 text-white">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_-10%,rgba(116,255,43,0.18),transparent_32rem),linear-gradient(180deg,#101214_0%,#08090a_56%)]"
      />
      <section aria-label="Lotzi coming soon" className="relative flex w-full max-w-[680px] flex-col items-center gap-6 text-center">
        <div className="inline-flex items-center gap-3.5" aria-label="Lotzi">
          <div className="grid h-16 w-16 place-items-center rounded-[18px] bg-[#74ff2b] shadow-[0_18px_44px_rgba(116,255,43,0.22)]">
            <svg aria-hidden="true" width="38" height="38" viewBox="0 0 38 38" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M10 7h7.2v19.4H29V32H10V7Z" fill="#070809" />
            </svg>
          </div>
          <div className="text-[clamp(34px,7vw,58px)] font-black leading-none">
            Lotzi
          </div>
        </div>

        <div className="w-full max-w-[580px] rounded-3xl border border-white/15 bg-white/[0.06] p-[clamp(26px,5vw,46px)] shadow-[0_24px_80px_rgba(0,0,0,0.34)]">
          <p className="mb-3.5 text-[13px] font-black uppercase text-[#74ff2b]">Launching soon</p>
          <h1 className="m-0 text-[clamp(36px,8vw,72px)] font-black leading-[0.96]">Coming soon</h1>
          <p className="mx-auto mt-5 max-w-[460px] text-[clamp(15px,2.5vw,18px)] font-semibold leading-[1.55] text-[#a3aab8]">
            We are building a location-first marketplace for parking, rentals, and services.
          </p>
          <p className="mt-7 border-t border-white/15 pt-5 text-sm font-extrabold text-[#d8dde7]">lotzi.in</p>
        </div>

        <Link className="text-xs font-semibold text-white/45 transition hover:text-white/75" href="/login">
          Admin sign in
        </Link>
      </section>
    </main>
  );
}
