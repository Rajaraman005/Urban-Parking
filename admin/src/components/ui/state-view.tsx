import Link from "next/link";
import { buttonClassName } from "./button";

export function EmptyState({
  actionHref,
  actionLabel,
  body,
  title
}: {
  actionHref?: string;
  actionLabel?: string;
  body: string;
  title: string;
}) {
  return (
    <div className="rounded-lg border border-dashed border-zinc-300 bg-white px-6 py-12 text-center shadow-[0_1px_2px_rgba(16,24,40,0.04)]">
      <h2 className="text-xl font-semibold text-zinc-950">{title}</h2>
      <p className="mx-auto mt-2 max-w-md text-sm leading-6 text-zinc-600">{body}</p>
      {actionHref && actionLabel ? (
        <Link href={actionHref} className={buttonClassName({ className: "mt-6", variant: "secondary" })}>
          {actionLabel}
        </Link>
      ) : null}
    </div>
  );
}

export function ErrorState({ body = "Something went wrong.", title = "Could not load data" }) {
  return (
    <div className="rounded-lg border border-red-200 bg-red-50 px-5 py-4 shadow-sm shadow-red-950/5">
      <h2 className="text-sm font-semibold text-red-950">{title}</h2>
      <p className="mt-1 text-sm text-red-800">{body}</p>
    </div>
  );
}
