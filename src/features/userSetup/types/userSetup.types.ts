import type {
  ParkingSpace,
  ParkingSpaceAvailabilityException,
  ParkingSpaceAvailabilityRule,
  ParkingSpacePhoto,
  ParkingSpaceStatus,
  ProfileAvatarUploadStatus,
  ParkingType,
  AddressProvider,
  SetupStep,
  UserIntent,
  UserProfile,
  VehicleFit
} from "@/lib/supabase/database.types";

export type {
  ParkingSpace,
  ParkingSpaceAvailabilityException,
  ParkingSpaceAvailabilityRule,
  ParkingSpacePhoto,
  ParkingSpaceStatus,
  ProfileAvatarUploadStatus,
  ParkingType,
  AddressProvider,
  SetupStep,
  UserIntent,
  VehicleFit
};

export interface UserSetupSnapshot {
  profile: UserProfile;
  draft: ParkingSpace | null;
  photos: ParkingSpacePhoto[];
}

export interface PricingAvailabilitySnapshot {
  draft: ParkingSpace;
}

export interface CloudinaryUploadSignature {
  apiKey: string;
  cloudName: string;
  expiresAt?: string;
  folder: string;
  publicId: string;
  signature: string;
  timestamp: number;
  uploadId?: string;
}

export interface CloudinaryUploadResult {
  bytes?: number;
  format?: string;
  height?: number;
  public_id: string;
  secure_url: string;
  width?: number;
}

export interface NormalizedAddressResult {
  city: string | null;
  confidence: number;
  formattedAddress: string;
  latitude: number;
  locality: string | null;
  longitude: number;
  placeId: string | null;
  postalCode: string | null;
  provider: AddressProvider;
  raw?: unknown;
}

export interface AddressSearchResponse {
  results: NormalizedAddressResult[];
}
