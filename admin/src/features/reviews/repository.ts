import "server-only";
import { unstable_noStore as noStore } from "next/cache";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { adminStatusForDb, dbStatusForAdmin, type AdminListingStatus } from "./status";
import type {
  ParkingPhotoRow,
  ParkingSpaceRow,
  ProfileRow,
  ReviewDetail,
  ReviewEvent,
  ReviewEventRow,
  ReviewListResult,
  ReviewPhoto
} from "./types";

const PAGE_SIZE = 12;
const fallbackImageUrl = "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";

const listSelect = [
  "id",
  "host_id",
  "title",
  "address",
  "locality",
  "city",
  "hourly_price",
  "slots_count",
  "vehicle_fit",
  "parking_type",
  "status",
  "submitted_at",
  "reviewed_at",
  "updated_at",
  "parking_space_photos(id,secure_url,sort_order,upload_status,width,height)"
].join(",");

const detailSelect = [
  "id",
  "host_id",
  "title",
  "address",
  "locality",
  "city",
  "postal_code",
  "latitude",
  "longitude",
  "address_provider",
  "address_confidence",
  "access_instructions",
  "hourly_price",
  "slots_count",
  "vehicle_fit",
  "parking_type",
  "status",
  "submitted_at",
  "reviewed_at",
  "updated_at",
  "deleted_at",
  "rejection_reason",
  "suspension_reason",
  "daily_start_minute",
  "daily_end_minute",
  "skip_weekends",
  "version",
  "parking_space_photos(id,secure_url,sort_order,upload_status,width,height)"
].join(",");

function cleanSearch(value: string) {
  return value.trim().replace(/[%(),]/g, " ").replace(/\s+/g, " ").slice(0, 80);
}

function text(value: string | null | undefined, fallback = "") {
  const normalized = value?.trim();
  return normalized && normalized.length > 0 ? normalized : fallback;
}

function linkedPhotos(photos?: ParkingPhotoRow[]): ReviewPhoto[] {
  return [...(photos ?? [])]
    .filter((photo) => photo.upload_status === "linked" && text(photo.secure_url).length > 0)
    .sort((left, right) => (left.sort_order ?? 999) - (right.sort_order ?? 999))
    .map((photo, index) => ({
      height: photo.height ?? undefined,
      id: photo.id ?? `${photo.secure_url}-${index}`,
      secureUrl: text(photo.secure_url),
      sortOrder: photo.sort_order ?? index,
      width: photo.width ?? undefined
    }));
}

async function profilesById(hostIds: string[]) {
  const uniqueIds = Array.from(new Set(hostIds));
  if (uniqueIds.length === 0) return new Map<string, ProfileRow>();
  const { data, error } = await getSupabaseAdmin()
    .from("profiles")
    .select("id,full_name,avatar_url,phone,role")
    .in("id", uniqueIds);
  if (error) throw new Error("Could not load listing owners.");
  return new Map((data as ProfileRow[]).map((profile) => [profile.id, profile]));
}

export async function listReviewListings(params: {
  page?: number;
  search?: string;
  status: AdminListingStatus;
}): Promise<ReviewListResult> {
  noStore();
  const page = Number.isInteger(params.page) && (params.page ?? 1) > 0 ? params.page ?? 1 : 1;
  const offset = (page - 1) * PAGE_SIZE;
  const search = cleanSearch(params.search ?? "");
  let query = getSupabaseAdmin()
    .from("parking_spaces")
    .select(listSelect, { count: "exact" })
    .eq("status", dbStatusForAdmin(params.status))
    .is("deleted_at", null);

  if (search.length >= 2) {
    const pattern = `%${search}%`;
    query = query.or(`title.ilike.${pattern},address.ilike.${pattern},locality.ilike.${pattern},city.ilike.${pattern}`);
  }

  const { count, data, error } = await query
    .order("submitted_at", { ascending: false, nullsFirst: false })
    .order("updated_at", { ascending: false })
    .range(offset, offset + PAGE_SIZE - 1);

  if (error) throw new Error("Could not load review listings.");

  const rows = (data ?? []) as unknown as ParkingSpaceRow[];
  const profiles = await profilesById(rows.map((row) => row.host_id));

  return {
    items: rows.map((row) => {
      const photos = linkedPhotos(row.parking_space_photos);
      const profile = profiles.get(row.host_id);
      return {
        address: text(row.address, "Address not provided"),
        city: text(row.city) || undefined,
        firstImageUrl: photos[0]?.secureUrl ?? fallbackImageUrl,
        hostName: text(profile?.full_name) || undefined,
        hourlyPrice: row.hourly_price ?? 0,
        id: row.id,
        locality: text(row.locality),
        photoCount: photos.length,
        reviewedAt: row.reviewed_at ?? undefined,
        slotsCount: row.slots_count ?? 0,
        status: adminStatusForDb(row.status),
        submittedAt: row.submitted_at ?? undefined,
        title: text(row.title, "Parking space"),
        vehicleFit: text(row.vehicle_fit) || undefined
      };
    }),
    page,
    pageCount: Math.max(1, Math.ceil((count ?? 0) / PAGE_SIZE)),
    pageSize: PAGE_SIZE,
    totalCount: count ?? 0
  };
}

async function reviewEventsFor(listingId: string): Promise<ReviewEvent[]> {
  const { data, error } = await getSupabaseAdmin()
    .from("parking_listing_review_events")
    .select("id,admin_user_id,event_type,previous_status,new_status,reason,internal_note,created_at")
    .eq("listing_id", listingId)
    .order("created_at", { ascending: false });

  if (error) return [];

  const rows = (data ?? []) as ReviewEventRow[];
  const adminIds = rows.map((row) => row.admin_user_id).filter((value): value is string => Boolean(value));
  const adminMap = new Map<string, { display_name: string; username: string }>();
  if (adminIds.length > 0) {
    const { data: admins } = await getSupabaseAdmin()
      .from("admin_users")
      .select("id,display_name,username")
      .in("id", Array.from(new Set(adminIds)));
    for (const admin of (admins ?? []) as Array<{ id: string; display_name: string; username: string }>) {
      adminMap.set(admin.id, admin);
    }
  }

  return rows.map((row) => {
    const admin = row.admin_user_id ? adminMap.get(row.admin_user_id) : undefined;
    return {
      adminDisplayName: admin?.display_name,
      adminUsername: admin?.username,
      createdAt: row.created_at,
      eventType: row.event_type,
      id: row.id,
      internalNote: text(row.internal_note) || undefined,
      newStatus: row.new_status ? adminStatusForDb(row.new_status) : undefined,
      previousStatus: row.previous_status ? adminStatusForDb(row.previous_status) : undefined,
      reason: text(row.reason) || undefined
    };
  });
}

export async function getReviewDetail(id: string): Promise<ReviewDetail | null> {
  noStore();
  const { data, error } = await getSupabaseAdmin()
    .from("parking_spaces")
    .select(detailSelect)
    .eq("id", id)
    .maybeSingle();

  if (error || !data) return null;

  const row = data as unknown as ParkingSpaceRow;
  const profiles = await profilesById([row.host_id]);
  const profile = profiles.get(row.host_id);
  const photos = linkedPhotos(row.parking_space_photos);

  return {
    accessInstructions: text(row.access_instructions) || undefined,
    address: text(row.address, "Address not provided"),
    addressConfidence: row.address_confidence ?? undefined,
    addressProvider: text(row.address_provider) || undefined,
    city: text(row.city) || undefined,
    dailyEndMinute: row.daily_end_minute ?? undefined,
    dailyStartMinute: row.daily_start_minute ?? undefined,
    deletedAt: row.deleted_at ?? undefined,
    events: await reviewEventsFor(row.id),
    host: {
      avatarUrl: text(profile?.avatar_url) || undefined,
      fullName: text(profile?.full_name) || undefined,
      id: row.host_id,
      phone: text(profile?.phone) || undefined,
      role: text(profile?.role) || undefined
    },
    hourlyPrice: row.hourly_price ?? 0,
    id: row.id,
    latitude: row.latitude ?? undefined,
    locality: text(row.locality),
    longitude: row.longitude ?? undefined,
    parkingType: text(row.parking_type) || undefined,
    photos,
    postalCode: text(row.postal_code) || undefined,
    rejectionReason: text(row.rejection_reason) || undefined,
    reviewedAt: row.reviewed_at ?? undefined,
    skipWeekends: row.skip_weekends ?? false,
    slotsCount: row.slots_count ?? 0,
    status: adminStatusForDb(row.status),
    submittedAt: row.submitted_at ?? undefined,
    suspensionReason: text(row.suspension_reason) || undefined,
    title: text(row.title, "Parking space"),
    updatedAt: row.updated_at ?? undefined,
    vehicleFit: text(row.vehicle_fit) || undefined,
    version: row.version ?? 1
  };
}

export async function transitionListing(params: {
  action: "approve" | "reject" | "suspend" | "note" | "soft_delete";
  adminUserId: string;
  internalNote?: string;
  listingId: string;
  reason?: string;
}) {
  const { error } = await getSupabaseAdmin().rpc("admin_transition_parking_listing", {
    p_action: params.action,
    p_admin_id: params.adminUserId,
    p_internal_note: params.internalNote ?? null,
    p_listing_id: params.listingId,
    p_metadata: {},
    p_reason: params.reason ?? null
  });

  if (error) {
    throw new Error(error.message || "Review action failed.");
  }
}
