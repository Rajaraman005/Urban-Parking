import Image from "next/image";
import Link from "next/link";
import { ArrowLeft, MapPin, Phone, UserRound } from "lucide-react";
import { StatusBadge } from "@/components/ui/badge";
import { buttonClassName } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { formatCurrency, formatDateTime, minuteLabel } from "@/lib/format";
import { ReviewActionPanel } from "./action-panel";
import type { ReviewDetail } from "./types";

export function ReviewDetailView({
  csrfToken,
  listing,
  toast
}: {
  csrfToken: string;
  listing: ReviewDetail;
  toast?: string;
}) {
  return (
    <div className="mx-auto max-w-[1500px] space-y-6">
      <Toast value={toast} />
      <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
        <div>
          <Link className="inline-flex items-center gap-2 text-sm font-semibold text-zinc-500 transition hover:text-zinc-950" href="/reviews">
            <ArrowLeft className="h-4 w-4" />
            Back to queue
          </Link>
          <div className="mt-4 flex flex-wrap items-center gap-3">
            <h1 className="text-[30px] font-semibold leading-9 text-zinc-950">{listing.title}</h1>
            <StatusBadge status={listing.status} />
          </div>
          <p className="mt-2 max-w-3xl text-[15px] leading-6 text-zinc-600">{listing.address}</p>
        </div>
        <Link
          className={buttonClassName({ variant: "secondary" })}
          href={
            typeof listing.latitude === "number" && typeof listing.longitude === "number"
              ? `https://www.google.com/maps/search/?api=1&query=${listing.latitude},${listing.longitude}`
              : "#"
          }
          target="_blank"
        >
          <MapPin className="h-4 w-4" />
          Open map
        </Link>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
        <div className="space-y-6">
          <ImageGallery listing={listing} />
          <section className="grid gap-4 md:grid-cols-3">
            <Metric label="Hourly price" value={formatCurrency(listing.hourlyPrice)} />
            <Metric label="Slots" value={String(listing.slotsCount)} />
            <Metric label="Vehicle fit" value={listing.vehicleFit ?? "Not set"} />
          </section>
          <section className="rounded-lg border border-zinc-200/80 bg-white p-6 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
            <h2 className="text-base font-semibold text-zinc-950">Listing details</h2>
            <dl className="mt-5 grid gap-x-8 gap-y-5 md:grid-cols-2">
              <Detail label="Locality" value={listing.locality || "Not set"} />
              <Detail label="City" value={listing.city ?? "Not set"} />
              <Detail label="PIN code" value={listing.postalCode ?? "Not set"} />
              <Detail label="Parking type" value={listing.parkingType ?? "Not set"} />
              <Detail label="Coordinates" value={coordinates(listing)} />
              <Detail label="Address provider" value={listing.addressProvider ?? "Not set"} />
              <Detail label="Daily hours" value={`${minuteLabel(listing.dailyStartMinute)} - ${minuteLabel(listing.dailyEndMinute)}`} />
              <Detail label="Weekends" value={listing.skipWeekends ? "Skipped" : "Allowed"} />
              <Detail label="Submitted" value={formatDateTime(listing.submittedAt)} />
              <Detail label="Updated" value={formatDateTime(listing.updatedAt)} />
            </dl>
            {listing.accessInstructions ? (
              <div className="mt-6 rounded-lg border border-zinc-200/80 bg-zinc-50/80 p-4">
                <div className="text-[11px] font-semibold uppercase text-zinc-500">Description</div>
                <p className="mt-2 text-sm leading-6 text-zinc-700">{listing.accessInstructions}</p>
              </div>
            ) : null}
          </section>
          <ReviewTimeline events={listing.events} />
        </div>

        <aside className="space-y-5 xl:sticky xl:top-24 xl:self-start">
          <ReviewActionPanel csrfToken={csrfToken} deletedAt={listing.deletedAt} listingId={listing.id} status={listing.status} />
          <section className="rounded-lg border border-zinc-200/80 bg-white p-5 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
            <h2 className="text-base font-semibold text-zinc-950">Owner</h2>
            <div className="mt-4 flex items-center gap-3">
              <div className="grid h-11 w-11 place-items-center rounded-full border border-zinc-200 bg-zinc-50">
                <UserRound className="h-5 w-5 text-zinc-500" />
              </div>
              <div className="min-w-0">
                <div className="truncate text-[15px] font-semibold text-zinc-950">{listing.host.fullName ?? "Unknown host"}</div>
                <div className="truncate text-xs text-zinc-500">{listing.host.id}</div>
              </div>
            </div>
            {listing.host.phone ? (
              <div className="mt-4 flex items-center gap-2 text-sm text-zinc-700">
                <Phone className="h-4 w-4 text-zinc-400" />
                {listing.host.phone}
              </div>
            ) : null}
          </section>
          {(listing.rejectionReason || listing.suspensionReason || listing.deletedAt) && (
            <section className="rounded-lg border border-zinc-200/80 bg-white p-5 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
              <h2 className="text-base font-semibold text-zinc-950">Review state</h2>
              {listing.rejectionReason ? <p className="mt-3 text-sm leading-6 text-red-700">{listing.rejectionReason}</p> : null}
              {listing.suspensionReason ? <p className="mt-3 text-sm leading-6 text-amber-700">{listing.suspensionReason}</p> : null}
              {listing.deletedAt ? <p className="mt-3 text-sm leading-6 text-zinc-600">Deleted {formatDateTime(listing.deletedAt)}</p> : null}
            </section>
          )}
        </aside>
      </div>
    </div>
  );
}

function ImageGallery({ listing }: { listing: ReviewDetail }) {
  if (listing.photos.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-zinc-300 bg-white p-8 text-center text-sm text-zinc-500 shadow-[0_1px_2px_rgba(16,24,40,0.04)]">
        No linked listing photos
      </div>
    );
  }
  return (
    <section className="grid gap-4 md:grid-cols-3">
      {listing.photos.map((photo, index) => (
        <div
          className="relative aspect-[4/3] overflow-hidden rounded-lg border border-zinc-200/80 bg-zinc-100 shadow-[0_1px_2px_rgba(16,24,40,0.08)]"
          key={photo.id}
        >
          <Image
            alt={`${listing.title} photo ${index + 1}`}
            className="object-cover"
            fill
            sizes="(min-width: 1024px) 30vw, 100vw"
            src={photo.secureUrl}
          />
        </div>
      ))}
    </section>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-zinc-200/80 bg-white p-5 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
      <div className="text-[11px] font-semibold uppercase text-zinc-500">{label}</div>
      <div className="mt-2 truncate text-xl font-semibold text-zinc-950">{value}</div>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[11px] font-semibold uppercase text-zinc-500">{label}</dt>
      <dd className="mt-1.5 break-words text-[15px] font-medium text-zinc-800">{value}</dd>
    </div>
  );
}

function ReviewTimeline({ events }: { events: ReviewDetail["events"] }) {
  return (
    <section className="rounded-lg border border-zinc-200/80 bg-white p-6 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
      <h2 className="text-base font-semibold text-zinc-950">Review history</h2>
      {events.length === 0 ? (
        <p className="mt-4 text-sm text-zinc-500">No review events yet.</p>
      ) : (
        <ol className="mt-4 space-y-4">
          {events.map((event) => (
            <li className="border-l-2 border-zinc-200 pl-4" key={event.id}>
              <div className="text-[15px] font-semibold text-zinc-950">{eventTitle(event.eventType)}</div>
              <div className="mt-1 text-xs text-zinc-500">
                {formatDateTime(event.createdAt)} / {event.adminDisplayName ?? event.adminUsername ?? "System"}
              </div>
              {event.reason ? <p className="mt-2 text-sm leading-6 text-zinc-700">{event.reason}</p> : null}
              {event.internalNote ? <p className="mt-2 text-sm leading-6 text-zinc-600">{event.internalNote}</p> : null}
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

function coordinates(listing: ReviewDetail) {
  if (typeof listing.latitude !== "number" || typeof listing.longitude !== "number") {
    return "Not set";
  }
  return `${listing.latitude.toFixed(6)}, ${listing.longitude.toFixed(6)}`;
}

function eventTitle(eventType: string) {
  return eventType
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}
