import Link from "next/link";

export default function NotFound() {
  return (
    <main className="grid min-h-screen place-items-center bg-[#f7f8fb] px-6">
      <div className="max-w-md text-center">
        <p className="text-sm font-semibold uppercase text-zinc-500">404</p>
        <h1 className="mt-3 text-3xl font-semibold text-zinc-950">Page not found</h1>
        <p className="mt-3 text-sm leading-6 text-zinc-600">The admin page you opened does not exist.</p>
        <Link
          href="/reviews"
          className="mt-6 inline-flex h-11 items-center rounded-lg bg-zinc-950 px-4 text-[15px] font-semibold text-white"
        >
          Back to review requests
        </Link>
      </div>
    </main>
  );
}
