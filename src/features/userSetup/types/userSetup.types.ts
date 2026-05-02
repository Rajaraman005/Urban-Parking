import type {
  ParkingSpace,
  ParkingSpaceAvailabilityException,
  ParkingSpaceAvailabilityRule,
  ParkingSpacePhoto,
  ParkingSpaceStatus,
  ProfileAvatarUploadStatus,
  ParkingType,
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
  blockedDates: string[];
  draft: ParkingSpace;
  rules: ParkingSpaceAvailabilityRule[];
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
