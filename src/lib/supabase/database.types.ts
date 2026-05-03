export type ProfileRole = "user" | "host" | "admin";
export type UserIntent = "park" | "host";
export type SetupStep = "intent" | "profile" | "host_basics" | "host_pricing" | "host_photos" | "host_review" | "complete";
export type ParkingSpaceStatus = "draft" | "pending_review" | "active" | "rejected";
export type VehicleFit = "bike" | "car" | "both";
export type ParkingType = "covered" | "open" | "garage" | "driveway" | "basement";
export type PhotoUploadStatus = "pending" | "uploaded" | "linked" | "failed";
export type ProfileAvatarUploadStatus = "signed" | "uploaded" | "completed" | "failed" | "cleanup_pending";
export type AddressProvider = "nominatim" | "manual";
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type UserProfile = {
  id: string;
  full_name: string | null;
  avatar_url: string | null;
  avatar_public_id: string | null;
  phone: string | null;
  gender: string | null;
  dob: string | null;
  role: ProfileRole;
  email_verified_at: string | null;
  intent: UserIntent | null;
  setup_step: SetupStep;
  setup_draft_id: string | null;
  onboarding_completed_at: string | null;
  version: number;
  created_at: string;
  updated_at: string;
};

export type ProfileAvatarUpload = {
  upload_id: string;
  user_id: string;
  public_id: string;
  secure_url: string | null;
  status: ProfileAvatarUploadStatus;
  sequence: number;
  completion_attempt_count: number;
  signature_timestamp: number;
  expires_at: string;
  created_at: string;
  updated_at: string;
};

export type AvatarCleanupQueueItem = {
  id: string;
  public_id: string;
  reason: string;
  attempt_count: number;
  next_attempt_at: string;
  created_at: string;
  updated_at: string;
};

export type ParkingSpace = {
  id: string;
  host_id: string;
  title: string | null;
  access_instructions: string | null;
  address: string | null;
  city: string | null;
  landmark: string | null;
  locality: string | null;
  postal_code: string | null;
  latitude: number | null;
  longitude: number | null;
  address_place_id: string | null;
  address_provider: AddressProvider | null;
  address_confidence: number | null;
  address_raw_osm_json: Json | null;
  location_confirmed_at: string | null;
  parking_type: ParkingType | null;
  vehicle_fit: VehicleFit | null;
  length_feet: number | null;
  width_feet: number | null;
  height_feet: number | null;
  slots_count: number;
  hourly_price: number | null;
  available_from_date: string | null;
  available_to_date: string | null;
  daily_start_minute: number | null;
  daily_end_minute: number | null;
  skip_weekends: boolean;
  availability_summary: string | null;
  status: ParkingSpaceStatus;
  version: number;
  submitted_at: string | null;
  created_at: string;
  updated_at: string;
};

export type ParkingSpacePhoto = {
  id: string;
  parking_space_id: string;
  host_id: string;
  public_id: string;
  secure_url: string;
  width: number | null;
  height: number | null;
  sort_order: number;
  upload_status: PhotoUploadStatus;
  created_at: string;
  updated_at: string;
};

export type ParkingSpaceAvailabilityRule = {
  id: string;
  parking_space_id: string;
  host_id: string;
  weekday: number;
  start_minute: number;
  end_minute: number;
  created_at: string;
  updated_at: string;
};

export type ParkingSpaceAvailabilityException = {
  id: string;
  parking_space_id: string;
  host_id: string;
  exception_date: string;
  is_available: boolean;
  created_at: string;
  updated_at: string;
};

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: UserProfile;
        Insert: {
          id: string;
          full_name?: string | null;
          avatar_url?: string | null;
          avatar_public_id?: string | null;
          phone?: string | null;
          gender?: string | null;
          dob?: string | null;
          role?: ProfileRole;
          email_verified_at?: string | null;
          intent?: UserIntent | null;
          setup_step?: SetupStep;
          setup_draft_id?: string | null;
          onboarding_completed_at?: string | null;
          version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          full_name?: string | null;
          phone?: string | null;
          gender?: string | null;
          dob?: string | null;
          email_verified_at?: string | null;
          intent?: UserIntent | null;
          setup_step?: SetupStep;
          setup_draft_id?: string | null;
          onboarding_completed_at?: string | null;
          version?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      profile_avatar_uploads: {
        Row: ProfileAvatarUpload;
        Insert: {
          upload_id: string;
          user_id: string;
          public_id: string;
          secure_url?: string | null;
          status?: ProfileAvatarUploadStatus;
          sequence: number;
          completion_attempt_count?: number;
          signature_timestamp: number;
          expires_at: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          secure_url?: string | null;
          status?: ProfileAvatarUploadStatus;
          sequence?: number;
          completion_attempt_count?: number;
          signature_timestamp?: number;
          expires_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      avatar_cleanup_queue: {
        Row: AvatarCleanupQueueItem;
        Insert: {
          id?: string;
          public_id: string;
          reason: string;
          attempt_count?: number;
          next_attempt_at?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          reason?: string;
          attempt_count?: number;
          next_attempt_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      parking_spaces: {
        Row: ParkingSpace;
        Insert: {
          id?: string;
          host_id: string;
          title?: string | null;
          access_instructions?: string | null;
          address?: string | null;
          city?: string | null;
          landmark?: string | null;
          locality?: string | null;
          postal_code?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          address_place_id?: string | null;
          address_provider?: AddressProvider | null;
          address_confidence?: number | null;
          address_raw_osm_json?: Json | null;
          location_confirmed_at?: string | null;
          parking_type?: ParkingType | null;
          vehicle_fit?: VehicleFit | null;
          length_feet?: number | null;
          width_feet?: number | null;
          height_feet?: number | null;
          slots_count?: number;
          hourly_price?: number | null;
          available_from_date?: string | null;
          available_to_date?: string | null;
          daily_start_minute?: number | null;
          daily_end_minute?: number | null;
          skip_weekends?: boolean;
          availability_summary?: string | null;
          status?: ParkingSpaceStatus;
          version?: number;
          submitted_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          title?: string | null;
          access_instructions?: string | null;
          address?: string | null;
          city?: string | null;
          landmark?: string | null;
          locality?: string | null;
          postal_code?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          address_place_id?: string | null;
          address_provider?: AddressProvider | null;
          address_confidence?: number | null;
          address_raw_osm_json?: Json | null;
          location_confirmed_at?: string | null;
          parking_type?: ParkingType | null;
          vehicle_fit?: VehicleFit | null;
          length_feet?: number | null;
          width_feet?: number | null;
          height_feet?: number | null;
          slots_count?: number;
          hourly_price?: number | null;
          available_from_date?: string | null;
          available_to_date?: string | null;
          daily_start_minute?: number | null;
          daily_end_minute?: number | null;
          skip_weekends?: boolean;
          availability_summary?: string | null;
          status?: ParkingSpaceStatus;
          version?: number;
          submitted_at?: string | null;
          updated_at?: string;
        };
        Relationships: [];
      };
      parking_space_photos: {
        Row: ParkingSpacePhoto;
        Insert: {
          id?: string;
          parking_space_id: string;
          host_id: string;
          public_id: string;
          secure_url: string;
          width?: number | null;
          height?: number | null;
          sort_order?: number;
          upload_status?: PhotoUploadStatus;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          secure_url?: string;
          width?: number | null;
          height?: number | null;
          sort_order?: number;
          upload_status?: PhotoUploadStatus;
          updated_at?: string;
        };
        Relationships: [];
      };
      parking_space_availability_rules: {
        Row: ParkingSpaceAvailabilityRule;
        Insert: {
          id?: string;
          parking_space_id: string;
          host_id: string;
          weekday: number;
          start_minute: number;
          end_minute: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          weekday?: number;
          start_minute?: number;
          end_minute?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      parking_space_availability_exceptions: {
        Row: ParkingSpaceAvailabilityException;
        Insert: {
          id?: string;
          parking_space_id: string;
          host_id: string;
          exception_date: string;
          is_available?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          exception_date?: string;
          is_available?: boolean;
          updated_at?: string;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      ensure_user_profile: {
        Args: {
          p_full_name?: string | null;
        };
        Returns: UserProfile;
      };
      submit_parking_space_for_review: {
        Args: {
          p_space_id: string;
          p_expected_version: number;
        };
        Returns: ParkingSpace;
      };
      save_parking_space_pricing_and_availability: {
        Args: {
          p_space_id: string;
          p_expected_version: number;
          p_hourly_price: number;
          p_length_feet: number;
          p_width_feet: number;
          p_height_feet: number | null;
          p_slots_count: number;
          p_availability_summary: string;
          p_rules: Json;
          p_blocked_dates: string[];
        };
        Returns: ParkingSpace;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
