import { ShieldCheck } from "lucide-react";
import { SubmitButton } from "@/components/ui/submit-button";
import { Toast } from "@/components/ui/toast";
import { changePasswordAction, revokeOtherSessionsAction } from "@/features/settings/actions";
import { listAdminSessions } from "@/features/settings/repository";
import { formatDateTime } from "@/lib/format";
import { csrfToken, requireAdmin } from "@/server/auth/session";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function SettingsPage({ searchParams }: { searchParams: SearchParams }) {
  const [session, token, params] = await Promise.all([requireAdmin(), csrfToken(), searchParams]);
  const sessions = await listAdminSessions(session.admin.id, session.id);

  return (
    <div className="mx-auto max-w-[1500px] space-y-6">
      <Toast value={single(params.toast)} />
      <div>
        <h1 className="text-[28px] font-semibold leading-9 text-zinc-950">Admin settings</h1>
        <p className="mt-1 text-[15px] text-zinc-600">Account and session controls for this admin user.</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <section className="rounded-lg border border-zinc-200/80 bg-white p-6 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
          <h2 className="text-base font-semibold text-zinc-950">Password</h2>
          <form action={changePasswordAction} className="mt-4 max-w-xl space-y-4">
            <input name="csrfToken" type="hidden" value={token} />
            <Field autoComplete="current-password" label="Current password" name="currentPassword" type="password" />
            <Field autoComplete="new-password" label="New password" name="newPassword" type="password" />
            <SubmitButton pendingLabel="Updating...">Update password</SubmitButton>
          </form>
        </section>

        <aside className="space-y-5">
          <section className="rounded-lg border border-zinc-200/80 bg-white p-5 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
            <div className="flex items-center gap-3">
              <div className="grid h-11 w-11 place-items-center rounded-full border border-emerald-200 bg-emerald-50">
                <ShieldCheck className="h-5 w-5 text-emerald-700" />
              </div>
              <div className="min-w-0">
                <div className="truncate text-[15px] font-semibold text-zinc-950">{session.admin.displayName}</div>
                <div className="truncate text-xs text-zinc-500">{session.admin.username}</div>
              </div>
            </div>
            <div className="mt-4 rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-[11px] font-semibold uppercase text-zinc-500">
              {session.admin.role}
            </div>
          </section>

          <section className="rounded-lg border border-zinc-200/80 bg-white p-5 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-base font-semibold text-zinc-950">Active sessions</h2>
              <form action={revokeOtherSessionsAction}>
                <input name="csrfToken" type="hidden" value={token} />
                <SubmitButton className="h-8 px-3 text-xs" pendingLabel="Revoking..." variant="secondary">
                  Revoke others
                </SubmitButton>
              </form>
            </div>
            <div className="mt-4 space-y-3">
              {sessions.map((item) => (
                <div className="rounded-lg border border-zinc-200 p-3" key={item.id}>
                  <div className="text-sm font-semibold text-zinc-950">{item.isCurrent ? "Current session" : "Admin session"}</div>
                  <div className="mt-1 text-xs text-zinc-500">Created {formatDateTime(item.createdAt)}</div>
                  <div className="mt-1 text-xs text-zinc-500">Expires {formatDateTime(item.expiresAt)}</div>
                </div>
              ))}
            </div>
          </section>
        </aside>
      </div>
    </div>
  );
}

function Field({
  label,
  name,
  type,
  autoComplete
}: {
  autoComplete: string;
  label: string;
  name: string;
  type: string;
}) {
  return (
    <label className="block">
      <span className="text-sm font-semibold text-zinc-800">{label}</span>
      <input
        autoComplete={autoComplete}
        className="mt-2 h-11 w-full rounded-lg border border-zinc-200 px-3 text-sm font-medium outline-none transition focus:border-zinc-500 focus:ring-4 focus:ring-zinc-100"
        name={name}
        required
        type={type}
      />
    </label>
  );
}

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}
