import Link from "next/link";
import { ClipboardCheck, LogOut, Settings, ShieldCheck, XCircle } from "lucide-react";
import { logoutAction } from "@/features/auth/actions";
import type { AdminUserDTO } from "@/server/auth/types";
import { buttonClassName } from "@/components/ui/button";

const nav = [
  { href: "/reviews", icon: ClipboardCheck, label: "Review Requests" },
  { href: "/approved", icon: ShieldCheck, label: "Approved Listings" },
  { href: "/rejected", icon: XCircle, label: "Rejected Listings" },
  { href: "/settings", icon: Settings, label: "Admin Settings" }
];

export function AdminShell({ admin, children }: { admin: AdminUserDTO; children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[#f7f8fb] text-zinc-950">
      <aside className="fixed inset-y-0 left-0 hidden w-[17.5rem] border-r border-zinc-200/80 bg-white lg:block">
        <div className="flex h-full flex-col">
          <div className="border-b border-zinc-200/80 px-6 py-6">
            <div className="text-[15px] font-extrabold uppercase text-zinc-950">Lotzi</div>
            <div className="mt-1 text-[13px] font-medium text-zinc-500">Admin console</div>
          </div>
          <nav className="flex-1 space-y-1.5 px-4 py-5">
            {nav.map((item) => (
              <Link
                className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-[15px] font-semibold text-zinc-700 transition hover:bg-zinc-100 hover:text-zinc-950"
                href={item.href}
                key={item.href}
              >
                <item.icon className="h-4 w-4 text-zinc-500" />
                {item.label}
              </Link>
            ))}
          </nav>
          <div className="border-t border-zinc-200/80 p-5">
            <div className="mb-3 rounded-lg border border-zinc-200/80 bg-zinc-50/80 p-3">
              <div className="truncate text-sm font-semibold text-zinc-950">{admin.displayName}</div>
              <div className="truncate text-xs text-zinc-500">{admin.username}</div>
            </div>
            <form action={logoutAction}>
              <button className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-[15px] font-semibold text-zinc-700 hover:bg-zinc-100 hover:text-zinc-950">
                <LogOut className="h-4 w-4 text-zinc-500" />
                Logout
              </button>
            </form>
          </div>
        </div>
      </aside>
      <div className="lg:pl-[17.5rem]">
        <header className="sticky top-0 z-30 border-b border-zinc-200/80 bg-white/90 backdrop-blur">
          <div className="flex min-h-[72px] items-center justify-between gap-4 px-5 lg:px-10">
            <div>
              <div className="text-sm font-semibold text-zinc-950 lg:hidden">Lotzi Admin</div>
              <div className="hidden text-[13px] font-medium text-zinc-500 lg:block">Secure listing review workflow</div>
            </div>
            <div className="flex items-center gap-3">
              <Link href="/reviews" className={buttonClassName({ className: "hidden sm:inline-flex", variant: "secondary" })}>
                Review queue
              </Link>
              <form action={logoutAction} className="lg:hidden">
                <button className={buttonClassName({ variant: "ghost" })} aria-label="Logout">
                  <LogOut className="h-4 w-4" />
                </button>
              </form>
            </div>
          </div>
          <nav className="flex gap-1 overflow-x-auto border-t border-zinc-100 px-3 py-2 lg:hidden">
            {nav.map((item) => (
              <Link
                className="inline-flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 text-xs font-semibold text-zinc-700 hover:bg-zinc-100"
                href={item.href}
                key={item.href}
              >
                <item.icon className="h-4 w-4" />
                {item.label}
              </Link>
            ))}
          </nav>
        </header>
        <main className="px-5 py-7 lg:px-10">{children}</main>
      </div>
    </div>
  );
}
