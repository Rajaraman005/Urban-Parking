import type { AdminListingStatus, DatabaseListingStatus } from "./status";

export interface ReviewListItem {
  address: string;
  city?: string;
  firstImageUrl?: string;
  hostName?: string;
  hourlyPrice: number;
  id: string;
  locality: string;
  photoCount: number;
  reviewedAt?: string;
  slotsCount: number;
  status: AdminListingStatus;
  submittedAt?: string;
  title: string;
  vehicleFit?: string;
}

export interface ReviewListResult {
  items: ReviewListItem[];
  page: number;
  pageCount: number;
  pageSize: number;
  totalCount: number;
}

export interface ReviewPhoto {
  height?: number;
  id: string;
  secureUrl: string;
  sortOrder: number;
  width?: number;
}

export interface ReviewEvent {
  adminDisplayName?: string;
  adminUsername?: string;
  createdAt: string;
  eventType: string;
  id: string;
  internalNote?: string;
  newStatus?: AdminListingStatus;
  previousStatus?: AdminListingStatus;
  reason?: string;
}

export interface ReviewDetail {
  accessInstructions?: string;
  address: string;
  addressConfidence?: number;
  addressProvider?: string;
  city?: string;
  dailyEndMinute?: number;
  dailyStartMinute?: number;
  deletedAt?: string;
  events: ReviewEvent[];
  host: {
    avatarUrl?: string;
    fullName?: string;
    id: string;
    phone?: string;
    role?: string;
  };
  hourlyPrice: number;
  id: string;
  latitude?: number;
  locality: string;
  longitude?: number;
  parkingType?: string;
  photos: ReviewPhoto[];
  postalCode?: string;
  rejectionReason?: string;
  reviewedAt?: string;
  skipWeekends: boolean;
  slotsCount: number;
  status: AdminListingStatus;
  submittedAt?: string;
  suspensionReason?: string;
  title: string;
  updatedAt?: string;
  vehicleFit?: string;
  version: number;
}

export interface ParkingSpaceRow {
  access_instructions?: string | null;
  address: string | null;
  address_confidence?: number | null;
  address_provider?: string | null;
  available_from_date?: string | null;
  available_to_date?: string | null;
  city?: string | null;
  daily_end_minute?: number | null;
  daily_start_minute?: number | null;
  deleted_at?: string | null;
  host_id: string;
  hourly_price: number | null;
  id: string;
  latitude?: number | null;
  locality: string | null;
  longitude?: number | null;
  parking_space_photos?: ParkingPhotoRow[];
  parking_type: string | null;
  postal_code?: string | null;
  rejection_reason?: string | null;
  reviewed_at?: string | null;
  skip_weekends?: boolean | null;
  slots_count: number | null;
  status: DatabaseListingStatus;
  submitted_at?: string | null;
  suspension_reason?: string | null;
  title: string | null;
  updated_at?: string | null;
  vehicle_fit: string | null;
  version?: number | null;
}

export interface ParkingPhotoRow {
  height?: number | null;
  id?: string;
  secure_url: string | null;
  sort_order: number | null;
  upload_status: string | null;
  width?: number | null;
}

export interface ProfileRow {
  avatar_url: string | null;
  full_name: string | null;
  id: string;
  phone: string | null;
  role: string | null;
}

export interface ReviewEventRow {
  admin_user_id: string | null;
  created_at: string;
  event_type: string;
  id: string;
  internal_note: string | null;
  new_status: string | null;
  previous_status: string | null;
  reason: string | null;
}
