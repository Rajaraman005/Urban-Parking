import { cn } from "@/lib/cn";
import { statusLabel, statusTone, type AdminListingStatus } from "@/features/reviews/status";

const tones = {
  amber: "border-amber-200 bg-amber-50 text-amber-800",
  blue: "border-sky-200 bg-sky-50 text-sky-700",
  green: "border-emerald-200 bg-emerald-50 text-emerald-700",
  red: "border-red-200 bg-red-50 text-red-700",
  zinc: "border-zinc-200 bg-zinc-50 text-zinc-700"
};

export function Badge({
  children,
  tone = "zinc"
}: {
  children: React.ReactNode;
  tone?: keyof typeof tones;
}) {
  return (
    <span className={cn("inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium", tones[tone])}>
      {children}
    </span>
  );
}

export function StatusBadge({ status }: { status: AdminListingStatus }) {
  return <Badge tone={statusTone[status]}>{statusLabel[status]}</Badge>;
}
