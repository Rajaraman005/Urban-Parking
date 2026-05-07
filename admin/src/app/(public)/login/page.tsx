import { LoginForm } from "./login-form";

export const dynamic = "force-dynamic";

export default function LoginPage() {
  return (
    <main className="grid min-h-screen place-items-center bg-[#f7f8fb] px-5 py-10">
      <section className="w-full max-w-md">
        <div className="mb-8">
          <div className="text-[15px] font-extrabold uppercase text-zinc-950">Urban Parking</div>
          <h1 className="mt-4 text-3xl font-semibold text-zinc-950">Admin sign in</h1>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Review submitted parking spaces and control public listing visibility.
          </p>
        </div>
        <div className="rounded-lg border border-zinc-200/80 bg-white p-6 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
          <LoginForm />
        </div>
      </section>
    </main>
  );
}
