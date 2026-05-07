import { AdminShell } from "@/components/layout/admin-shell";
import { requireAdmin } from "@/server/auth/session";

export const dynamic = "force-dynamic";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const session = await requireAdmin();
  return <AdminShell admin={session.admin}>{children}</AdminShell>;
}
