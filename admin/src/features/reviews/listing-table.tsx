import Image from "next/image";
import Link from "next/link";
import { Search } from "lucide-react";
import { StatusBadge } from "@/components/ui/badge";
import { buttonClassName } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/state-view";
import { formatCurrency, formatDateTime } from "@/lib/format";
import { statusDescription, statusLabel, type AdminListingStatus } from "./status";
import type { ReviewListResult } from "./types";

function pageHref(basePath: string, page: number, search?: string) {
  const params = new URLSearchParams();
  if (search) params.set("q", search);
  if (page > 1) params.set("page", String(page));
  const suffix = params.toString();
  return suffix ? `${basePath}?${suffix}` : basePath;
}

export function ReviewIndex({
  basePath,
  result,
  search,
  status,
  toast
}: {
  basePath: string;
  result: ReviewListResult;
  search?: string;
  status: AdminListingStatus;
  toast?: React.ReactNode;
}) {
  return (
    <div className="mx-auto max-w-[1500px] space-y-6">
      {toast}
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-[28px] font-semibold leading-9 text-zinc-950">{statusLabel[status]} listings</h1>
          <p className="mt-1 text-[15px] text-zinc-600">{statusDescription(status)}</p>
        </div>
        <form className="flex w-full gap-2 md:w-[360px]" action={basePath}>
          <div className="flex h-11 min-w-0 flex-1 items-center gap-2 rounded-lg border border-zinc-200 bg-white px-3 shadow-sm shadow-zinc-950/[0.03] focus-within:border-zinc-400 focus-within:ring-4 focus-within:ring-zinc-100">
            <Search className="h-4 w-4 shrink-0 text-zinc-400" />
            <input
              className="min-w-0 flex-1 border-0 bg-transparent text-sm outline-none placeholder:text-zinc-400"
              defaultValue={search}
              name="q"
              placeholder="Search listings"
              type="search"
            />
          </div>
          <button className={buttonClassName({ variant: "secondary" })}>Search</button>
        </form>
      </div>

      {result.items.length === 0 ? (
        <EmptyState
          body={search ? "No listings matched the current search." : "There are no listings in this queue."}
          title="Nothing here"
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-zinc-200/80 bg-white shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-zinc-200">
              <thead className="bg-zinc-50">
                <tr>
                  <th className="px-4 py-3 text-left text-[11px] font-semibold uppercase text-zinc-500">
                    Listing
                  </th>
                  <th className="px-4 py-3 text-left text-[11px] font-semibold uppercase text-zinc-500">
                    Owner
                  </th>
                  <th className="px-4 py-3 text-left text-[11px] font-semibold uppercase text-zinc-500">
                    Pricing
                  </th>
                  <th className="px-4 py-3 text-left text-[11px] font-semibold uppercase text-zinc-500">
                    Submitted
                  </th>
                  <th className="px-4 py-3 text-left text-[11px] font-semibold uppercase text-zinc-500">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {result.items.map((item) => (
                  <tr className="transition hover:bg-zinc-50/80" key={item.id}>
                    <td className="px-4 py-4">
                      <Link className="flex min-w-[280px] items-center gap-3" href={`/reviews/${item.id}`}>
                        <Image
                          alt=""
                          className="h-12 w-16 rounded-lg object-cover"
                          height={96}
                          src={item.firstImageUrl ?? ""}
                          width={128}
                        />
                        <span className="min-w-0">
                          <span className="block truncate text-[15px] font-semibold text-zinc-950">{item.title}</span>
                          <span className="mt-1 block truncate text-xs text-zinc-500">{item.address}</span>
                        </span>
                      </Link>
                    </td>
                    <td className="px-4 py-4 text-sm font-medium text-zinc-700">{item.hostName ?? "Unknown host"}</td>
                    <td className="px-4 py-4 text-sm text-zinc-700">
                      <div className="font-semibold text-zinc-950">{formatCurrency(item.hourlyPrice)}</div>
                      <div className="text-xs text-zinc-500">{item.slotsCount} slots</div>
                    </td>
                    <td className="px-4 py-4 text-sm text-zinc-700">{formatDateTime(item.submittedAt)}</td>
                    <td className="px-4 py-4">
                      <StatusBadge status={item.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex items-center justify-between border-t border-zinc-200 px-4 py-3">
            <div className="text-sm text-zinc-500">
              Page {result.page} of {result.pageCount} / {result.totalCount} listings
            </div>
            <div className="flex gap-2">
              <Link
                aria-disabled={result.page <= 1}
                className={buttonClassName({
                  className: result.page <= 1 ? "pointer-events-none opacity-50" : "",
                  variant: "secondary"
                })}
                href={pageHref(basePath, Math.max(1, result.page - 1), search)}
              >
                Previous
              </Link>
              <Link
                aria-disabled={result.page >= result.pageCount}
                className={buttonClassName({
                  className: result.page >= result.pageCount ? "pointer-events-none opacity-50" : "",
                  variant: "secondary"
                })}
                href={pageHref(basePath, Math.min(result.pageCount, result.page + 1), search)}
              >
                Next
              </Link>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
