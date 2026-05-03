import type * as ImagePicker from "expo-image-picker";
import * as Crypto from "expo-crypto";
import { manipulateAsync, SaveFormat } from "expo-image-manipulator";

import { env } from "@/config/env";
import { AppAuthError } from "@/features/auth/services/authErrors";
import { authService } from "@/features/auth/services/authService";
import type {
  HostBasicsValues,
  HostLocationValues,
  HostPricingValues,
  ProfileSetupValues
} from "@/features/userSetup/schemas/userSetupSchemas";
import type {
  CloudinaryUploadResult,
  CloudinaryUploadSignature,
  AddressSearchResponse,
  NormalizedAddressResult,
  ParkingSpace,
  ParkingSpacePhoto,
  PricingAvailabilitySnapshot,
  UserIntent,
  UserSetupSnapshot
} from "@/features/userSetup/types/userSetup.types";
import { formatBoundedAvailabilitySummary } from "@/features/userSetup/utils/availability";
import { supabase } from "@/lib/supabase/client";
import type { Database, UserProfile } from "@/lib/supabase/database.types";
import { logger } from "@/utils/logger";

const MAX_PHOTOS = 5;
const MIN_PHOTOS = 2;
const allowedMimeTypes = new Set(["image/jpeg", "image/jpg", "image/png", "image/webp", "image/heic", "image/heif"]);
const MAX_AVATAR_BYTES = 5 * 1024 * 1024;
const MIN_AVATAR_DIMENSION = 256;
const allowedAvatarMimeTypes = new Set(["image/jpeg", "image/jpg", "image/png", "image/webp"]);

type ProfilePatch = Pick<UserProfile, "intent" | "setup_step"> &
  Partial<Pick<UserProfile, "full_name" | "phone" | "setup_draft_id" | "onboarding_completed_at" | "gender" | "dob">>;
type ParkingSpaceUpdate = Database["public"]["Tables"]["parking_spaces"]["Update"];

const nowIso = () => new Date().toISOString();
const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const legacyWeekdays = {
  allDays: [0, 1, 2, 3, 4, 5, 6],
  weekdaysOnly: [1, 2, 3, 4, 5]
} as const;

const assertCloudinaryConfigured = () => {
  if (!env.cloudinaryCloudName) {
    throw new AppAuthError("configuration", "Cloudinary is not configured for this build.");
  }
};

const requireSession = async () => authService.getCurrentSessionStrict();

const assertAddressLookupResponse = async <T>(response: Response, fallbackMessage: string): Promise<T> =>
  assertFunctionResponse<T>(response, fallbackMessage);

const assertSingleRow = <T>(row: T | null, message: string) => {
  if (!row) {
    throw new AppAuthError("server", message, "stale_write");
  }

  return row;
};

const isMissingAvailabilityColumnError = (error: unknown) => {
  const message =
    typeof error === "object" && error !== null && "message" in error && typeof error.message === "string"
      ? error.message
      : "";
  const code =
    typeof error === "object" && error !== null && "code" in error && typeof error.code === "string" ? error.code : "";

  return (
    code === "PGRST204" ||
    message.includes("available_from_date") ||
    message.includes("available_to_date") ||
    message.includes("daily_start_minute") ||
    message.includes("daily_end_minute") ||
    message.includes("skip_weekends")
  );
};

const inferMimeType = (asset: ImagePicker.ImagePickerAsset) => {
  if (asset.mimeType) {
    return asset.mimeType.toLowerCase();
  }

  const extension = asset.uri.split(".").pop()?.toLowerCase();

  switch (extension) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "png":
      return "image/png";
    case "webp":
      return "image/webp";
    case "heic":
      return "image/heic";
    case "heif":
      return "image/heif";
    default:
      return "image/jpeg";
  }
};

const fileNameForAsset = (asset: ImagePicker.ImagePickerAsset) =>
  asset.fileName ?? `parking-space-${Date.now()}.${inferMimeType(asset).split("/")[1] ?? "jpg"}`;

const fileNameForAvatarAsset = (asset: ImagePicker.ImagePickerAsset) =>
  asset.fileName ?? `profile-avatar-${Date.now()}.${inferMimeType(asset).split("/")[1] ?? "jpg"}`;

const normalizeProfileAvatarAsset = async (asset: ImagePicker.ImagePickerAsset): Promise<ImagePicker.ImagePickerAsset> => {
  if (asset.width < MIN_AVATAR_DIMENSION || asset.height < MIN_AVATAR_DIMENSION) {
    throw new AppAuthError("validation", "Profile photo must be at least 256px wide and tall.");
  }

  const maxSide = 1024;
  const resize =
    asset.width >= asset.height
      ? { width: Math.min(asset.width, maxSide) }
      : { height: Math.min(asset.height, maxSide) };
  const normalized = await manipulateAsync(asset.uri, [{ resize }], {
    compress: 0.82,
    format: SaveFormat.JPEG
  });

  return {
    ...asset,
    fileName: `profile-avatar-${Date.now()}.jpg`,
    fileSize: undefined,
    height: normalized.height,
    mimeType: "image/jpeg",
    uri: normalized.uri,
    width: normalized.width
  };
};

const assertFunctionResponse = async <T>(
  response: Response,
  fallbackMessage: string
): Promise<T> => {
  const payload = (await response.json().catch(() => null)) as
    | { ok: true; data: T }
    | { ok: false; message?: string; code?: string }
    | null;

  if (!payload) {
    if (response.status === 429) {
      throw new AppAuthError("rate_limit", "Too many attempts. Please wait before trying again.", "rate_limit");
    }

    throw new AppAuthError("server", fallbackMessage);
  }

  if (!payload.ok) {
    const category =
      response.status === 429
        ? "rate_limit"
        : response.status === 0 || response.status >= 500
          ? "server"
          : response.status === 401 || response.status === 403
            ? "auth"
            : "validation";
    throw new AppAuthError(category, payload.message ?? fallbackMessage, payload.code);
  }

  if (!response.ok) {
    throw new AppAuthError("server", fallbackMessage);
  }

  return payload.data;
};

const updateProfileWithLock = async (profile: UserProfile, patch: ProfilePatch) => {
  const { data, error } = await supabase
    .from("profiles")
    .update({
      ...patch,
      version: profile.version + 1
    })
    .eq("id", profile.id)
    .eq("version", profile.version)
    .select("*")
    .maybeSingle();

  if (error) {
    throw error;
  }

  return assertSingleRow(data, "This setup changed on another device. Reload and continue with the latest version.");
};

const updateDraftWithLock = async (
  draftId: string,
  expectedVersion: number,
  patch: ParkingSpaceUpdate
) => {
  const { data, error } = await supabase
    .from("parking_spaces")
    .update({
      ...patch,
      version: expectedVersion + 1,
      updated_at: nowIso()
    })
    .eq("id", draftId)
    .eq("version", expectedVersion)
    .eq("status", "draft")
    .select("*")
    .maybeSingle();

  if (error) {
    throw error;
  }

  return assertSingleRow(data, "This draft changed on another device. Reload and continue with the latest draft.");
};

const saveHostPricingLegacy = async (draft: ParkingSpace, values: HostPricingValues, availabilitySummary: string) => {
  const { data, error } = await supabase.rpc("save_parking_space_pricing_and_availability", {
    p_availability_summary: availabilitySummary,
    p_blocked_dates: [],
    p_expected_version: draft.version,
    p_height_feet: values.heightFeet ?? null,
    p_hourly_price: values.hourlyPrice,
    p_length_feet: values.lengthFeet,
    p_rules: (values.skipWeekends ? legacyWeekdays.weekdaysOnly : legacyWeekdays.allDays).map((weekday) => ({
      end_minute: values.dailyEndMinute,
      start_minute: values.dailyStartMinute,
      weekday
    })),
    p_slots_count: values.slotsCount,
    p_space_id: draft.id,
    p_width_feet: values.widthFeet
  });

  if (error) {
    throw error;
  }

  return assertSingleRow(data, "This draft changed on another device. Reload and continue with the latest draft.");
};

const loadPhotos = async (parkingSpaceId: string) => {
  const { data, error } = await supabase
    .from("parking_space_photos")
    .select("*")
    .eq("parking_space_id", parkingSpaceId)
    .order("sort_order", { ascending: true });

  if (error) {
    throw error;
  }

  return data ?? [];
};

export const userSetupService = {
  async loadSnapshot(): Promise<UserSetupSnapshot> {
    const profile = await authService.ensureProfile();
    const draft = profile.setup_draft_id ? await this.loadDraft(profile.setup_draft_id) : null;
    const photos = draft ? await loadPhotos(draft.id) : [];

    return { profile, draft, photos };
  },

  async saveIntent(intent: UserIntent) {
    const profile = await authService.ensureProfile();

    if (intent === "host") {
      const draft = await this.getOrCreateHostDraft(profile);
      const updatedProfile = await updateProfileWithLock(profile, {
        intent,
        setup_step: "profile",
        setup_draft_id: draft.id
      });

      return { profile: updatedProfile, draft };
    }

    const updatedProfile = await updateProfileWithLock(profile, {
      intent,
      setup_step: "profile",
      setup_draft_id: null
    });

    return { profile: updatedProfile, draft: null };
  },

  async saveProfile(values: ProfileSetupValues, intent: UserIntent) {
    const profile = await authService.ensureProfile();
    const nextStep = intent === "host" ? "host_basics" : "complete";
    const completedAt = intent === "park" ? nowIso() : null;
    const draft = intent === "host" ? await this.getOrCreateHostDraft(profile) : null;

    // Convert DD/MM/YYYY to YYYY-MM-DD for PostgreSQL date column
    const [day, month, year] = values.dob.split("/");
    const dobFormatted = `${year}-${month}-${day}`;

    const updatedProfile = await updateProfileWithLock(profile, {
      full_name: values.fullName.trim(),
      phone: values.phone.trim(),
      gender: values.gender,
      dob: dobFormatted,
      intent,
      setup_step: nextStep,
      setup_draft_id: draft?.id ?? null,
      onboarding_completed_at: completedAt
    });

    return { profile: updatedProfile, draft };
  },

  async getOrCreateHostDraft(profile?: UserProfile) {
    const session = await requireSession();
    const currentProfile = profile ?? (await authService.ensureProfile());

    if (currentProfile.setup_draft_id) {
      const draft = await this.loadDraft(currentProfile.setup_draft_id);

      if (draft.status === "draft") {
        return draft;
      }
    }

    const { data, error } = await supabase
      .from("parking_spaces")
      .insert({
        host_id: session.user.id,
        status: "draft",
        title: "Parking space"
      })
      .select("*")
      .single();

    if (error) {
      throw error;
    }

    return data;
  },

  async loadDraft(draftId: string) {
    const { data, error } = await supabase.from("parking_spaces").select("*").eq("id", draftId).maybeSingle();

    if (error) {
      throw error;
    }

    return assertSingleRow(data, "We could not find your saved parking draft.");
  },

  async loadDraftWithPhotos(draftId: string) {
    const [draft, photos] = await Promise.all([this.loadDraft(draftId), loadPhotos(draftId)]);

    return { draft, photos };
  },

  async loadPricingAvailabilitySnapshot(draftId: string): Promise<PricingAvailabilitySnapshot> {
    const draft = await this.loadDraft(draftId);

    return { draft };
  },

  async saveHostBasics(draft: ParkingSpace, values: HostBasicsValues) {
    const updated = await updateDraftWithLock(draft.id, draft.version, {
      access_instructions: values.accessInstructions?.trim() || null,
      address: values.address.trim(),
      address_confidence: values.addressConfidence,
      address_place_id: values.addressPlaceId,
      address_provider: values.addressProvider,
      address_raw_osm_json: values.addressRawOsmJson as Database["public"]["Tables"]["parking_spaces"]["Update"]["address_raw_osm_json"],
      city: values.city.trim(),
      landmark: values.landmark?.trim() || null,
      latitude: values.latitude,
      locality: values.locality.trim(),
      location_confirmed_at: values.locationConfirmedAt,
      longitude: values.longitude,
      parking_type: values.parkingType,
      postal_code: values.postalCode.trim(),
      title: `${values.vehicleFit === "bike" ? "Bike" : values.vehicleFit === "car" ? "Car" : "Bike and car"} parking`,
      vehicle_fit: values.vehicleFit
    });
    const profile = await authService.ensureProfile();
    await updateProfileWithLock(profile, { intent: "host", setup_step: "host_pricing", setup_draft_id: draft.id });

    return updated;
  },

  async saveHostLocation(draft: ParkingSpace, values: HostLocationValues) {
    return updateDraftWithLock(draft.id, draft.version, {
      address: values.address?.trim() || null,
      address_confidence: values.addressConfidence,
      address_place_id: values.addressPlaceId,
      address_provider: values.addressProvider,
      address_raw_osm_json: values.addressRawOsmJson as Database["public"]["Tables"]["parking_spaces"]["Update"]["address_raw_osm_json"],
      city: values.city?.trim() || null,
      latitude: values.latitude,
      locality: values.locality?.trim() || null,
      location_confirmed_at: values.locationConfirmedAt,
      longitude: values.longitude,
      postal_code: values.postalCode?.trim() || null
    });
  },

  async searchAddress(query: string) {
    const session = await requireSession();
    const response = await fetch(`${env.supabaseUrl}/functions/v1/search-address`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        apikey: env.supabaseAnonKey,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ query })
    });

    return assertAddressLookupResponse<AddressSearchResponse>(response, "Address search is temporarily unavailable.");
  },

  async reverseGeocodeAddress(latitude: number, longitude: number) {
    const session = await requireSession();
    const response = await fetch(`${env.supabaseUrl}/functions/v1/reverse-geocode-address`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        apikey: env.supabaseAnonKey,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ latitude, longitude })
    });

    return assertAddressLookupResponse<{ result: NormalizedAddressResult | null }>(
      response,
      "Map lookup is temporarily unavailable."
    );
  },

  async saveHostPricing(draft: ParkingSpace, values: HostPricingValues) {
    const availabilitySummary = formatBoundedAvailabilitySummary(
      values.availableFromDate,
      values.availableToDate,
      values.dailyStartMinute,
      values.dailyEndMinute,
      values.skipWeekends
    );
    let updated: ParkingSpace;

    try {
      updated = await updateDraftWithLock(draft.id, draft.version, {
        available_from_date: values.availableFromDate,
        available_to_date: values.availableToDate,
        availability_summary: availabilitySummary,
        daily_end_minute: values.dailyEndMinute,
        daily_start_minute: values.dailyStartMinute,
        height_feet: values.heightFeet ?? null,
        hourly_price: values.hourlyPrice,
        length_feet: values.lengthFeet,
        skip_weekends: values.skipWeekends,
        slots_count: values.slotsCount,
        width_feet: values.widthFeet
      });
      const [rulesDeleteResult, exceptionsDeleteResult] = await Promise.all([
        supabase.from("parking_space_availability_rules").delete().eq("parking_space_id", draft.id),
        supabase.from("parking_space_availability_exceptions").delete().eq("parking_space_id", draft.id)
      ]);

      if (rulesDeleteResult.error) {
        throw rulesDeleteResult.error;
      }

      if (exceptionsDeleteResult.error) {
        throw exceptionsDeleteResult.error;
      }
    } catch (error) {
      if (!isMissingAvailabilityColumnError(error)) {
        throw error;
      }

      updated = await saveHostPricingLegacy(draft, values, availabilitySummary);
    }

    const profile = await authService.ensureProfile();
    await updateProfileWithLock(profile, { intent: "host", setup_step: "host_photos", setup_draft_id: draft.id });

    return updated;
  },

  async validatePhotoAsset(asset: ImagePicker.ImagePickerAsset, existingPhotoCount: number) {
    if (existingPhotoCount >= MAX_PHOTOS) {
      throw new AppAuthError("validation", "You can upload up to 5 photos.");
    }

    const mimeType = inferMimeType(asset);

    if (!allowedMimeTypes.has(mimeType)) {
      throw new AppAuthError("validation", "Upload a JPG, PNG, WebP, HEIC, or HEIF image.");
    }

  },

  validateProfileAvatarAsset(asset: ImagePicker.ImagePickerAsset) {
    const mimeType = inferMimeType(asset);

    if (!allowedAvatarMimeTypes.has(mimeType)) {
      throw new AppAuthError("validation", "Upload a JPG, PNG, or WebP profile photo.");
    }

    if (asset.fileSize && asset.fileSize > MAX_AVATAR_BYTES) {
      throw new AppAuthError("validation", "Profile photo must be 5MB or smaller.");
    }

    if (asset.width < MIN_AVATAR_DIMENSION || asset.height < MIN_AVATAR_DIMENSION) {
      throw new AppAuthError("validation", "Profile photo must be at least 256px wide and tall.");
    }
  },

  async requestProfileAvatarSignature(
    uploadId: string,
    sequence: number,
    asset: ImagePicker.ImagePickerAsset
  ) {
    assertCloudinaryConfigured();
    const session = await requireSession();
    const response = await fetch(`${env.supabaseUrl}/functions/v1/create-profile-avatar-upload-signature`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        apikey: env.supabaseAnonKey,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        fileName: fileNameForAvatarAsset(asset),
        fileSize: asset.fileSize ?? null,
        height: asset.height,
        mimeType: inferMimeType(asset),
        sequence,
        uploadId,
        width: asset.width
      })
    });

    return assertFunctionResponse<CloudinaryUploadSignature>(
      response,
      "Profile photo upload could not be prepared."
    );
  },

  async completeProfileAvatarUpload(
    uploadId: string,
    sequence: number,
    result: CloudinaryUploadResult
  ) {
    const session = await requireSession();
    const response = await fetch(`${env.supabaseUrl}/functions/v1/complete-profile-avatar-upload`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        apikey: env.supabaseAnonKey,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        bytes: result.bytes ?? null,
        format: result.format ?? null,
        height: result.height ?? null,
        publicId: result.public_id,
        secureUrl: result.secure_url,
        sequence,
        uploadId,
        width: result.width ?? null
      })
    });

    return assertFunctionResponse<{ profile: UserProfile }>(
      response,
      "Profile photo could not be saved."
    );
  },

  async uploadProfileAvatar(asset: ImagePicker.ImagePickerAsset, sequence: number) {
    const normalizedAsset = await normalizeProfileAvatarAsset(asset);
    this.validateProfileAvatarAsset(normalizedAsset);
    const uploadId = Crypto.randomUUID();
    const signature = await this.requestProfileAvatarSignature(uploadId, sequence, normalizedAsset);
    const mimeType = inferMimeType(normalizedAsset);
    const formData = new FormData();

    logger.info("profile_avatar_signature_requested");

    formData.append("file", {
      uri: normalizedAsset.uri,
      type: mimeType,
      name: fileNameForAvatarAsset(normalizedAsset)
    } as unknown as Blob);
    formData.append("api_key", signature.apiKey);
    formData.append("timestamp", String(signature.timestamp));
    formData.append("signature", signature.signature);
    formData.append("public_id", signature.publicId);

    const cloudinaryResponse = await fetch(
      `https://api.cloudinary.com/v1_1/${signature.cloudName || env.cloudinaryCloudName}/image/upload`,
      {
        body: formData,
        method: "POST"
      }
    );
    const result = (await cloudinaryResponse.json().catch(() => null)) as CloudinaryUploadResult | null;

    if (!cloudinaryResponse.ok || !result?.public_id || !result.secure_url) {
      logger.warn("profile_avatar_upload_failed", { code: "cloudinary_upload_failed" });
      throw new AppAuthError("server", "Profile photo upload failed. Please try again.", "cloudinary_upload_failed");
    }

    let completion: { profile: UserProfile } | null = null;
    let completionError: unknown;

    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        completion = await this.completeProfileAvatarUpload(uploadId, sequence, result);
        break;
      } catch (error) {
        completionError = error;

        if (error instanceof AppAuthError && error.category !== "server" && error.category !== "network") {
          throw error;
        }

        await delay(400 * (attempt + 1));
      }
    }

    if (!completion) {
      throw completionError;
    }

    logger.info("profile_avatar_upload_completed");

    return completion.profile;
  },

  async requestCloudinarySignature(draftId: string, asset: ImagePicker.ImagePickerAsset) {
    assertCloudinaryConfigured();
    const session = await requireSession();
    const response = await fetch(`${env.supabaseUrl}/functions/v1/create-cloudinary-upload-signature`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        apikey: env.supabaseAnonKey,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        fileName: fileNameForAsset(asset),
        fileSize: asset.fileSize ?? null,
        height: asset.height,
        mimeType: inferMimeType(asset),
        parkingSpaceId: draftId,
        width: asset.width
      })
    });
    const payload = (await response.json().catch(() => null)) as
      | { ok: true; data: CloudinaryUploadSignature }
      | { ok: false; message?: string; code?: string }
      | null;

    if (!payload) {
      throw new AppAuthError("server", "Photo upload could not be prepared.");
    }

    if (!payload.ok) {
      const category =
        response.status === 401 || response.status === 403
          ? "auth"
          : response.status === 400
            ? "validation"
            : "server";
      throw new AppAuthError(category, payload.message ?? "Photo upload could not be prepared.", payload.code);
    }

    if (!response.ok) {
      throw new AppAuthError("server", "Photo upload could not be prepared.");
    }

    return payload.data;
  },

  async uploadPhoto(draftId: string, asset: ImagePicker.ImagePickerAsset, sortOrder: number) {
    await this.validatePhotoAsset(asset, sortOrder);
    const session = await requireSession();
    const signature = await this.requestCloudinarySignature(draftId, asset);
    const mimeType = inferMimeType(asset);
    const formData = new FormData();

    formData.append("file", {
      uri: asset.uri,
      type: mimeType,
      name: fileNameForAsset(asset)
    } as unknown as Blob);
    formData.append("api_key", signature.apiKey);
    formData.append("timestamp", String(signature.timestamp));
    formData.append("signature", signature.signature);
    formData.append("folder", signature.folder);
    formData.append("public_id", signature.publicId);

    const cloudinaryResponse = await fetch(
      `https://api.cloudinary.com/v1_1/${signature.cloudName || env.cloudinaryCloudName}/image/upload`,
      {
        body: formData,
        method: "POST"
      }
    );
    const result = (await cloudinaryResponse.json().catch(() => null)) as CloudinaryUploadResult | null;

    if (!cloudinaryResponse.ok || !result?.public_id || !result.secure_url) {
      logger.warn("profile_sync_failed", { code: "cloudinary_upload_failed" });
      throw new AppAuthError("server", "Photo upload failed. Please try again.", "cloudinary_upload_failed");
    }

    const { data, error } = await supabase
      .from("parking_space_photos")
      .insert({
        height: result.height ?? asset.height,
        host_id: session.user.id,
        parking_space_id: draftId,
        public_id: result.public_id,
        secure_url: result.secure_url,
        sort_order: sortOrder,
        upload_status: "linked",
        width: result.width ?? asset.width
      })
      .select("*")
      .single();

    if (error) {
      throw error;
    }

    return data;
  },

  async deletePhoto(photo: ParkingSpacePhoto) {
    const { error } = await supabase.from("parking_space_photos").delete().eq("id", photo.id);

    if (error) {
      throw error;
    }
  },

  async markPhotosStepComplete(draftId: string) {
    const photos = await loadPhotos(draftId);

    if (photos.length < MIN_PHOTOS) {
      throw new AppAuthError("validation", "Add at least 2 clear parking space photos.");
    }

    const profile = await authService.ensureProfile();
    await updateProfileWithLock(profile, { intent: "host", setup_step: "host_review", setup_draft_id: draftId });
  },

  async submitForReview(draft: ParkingSpace) {
    const { data, error } = await supabase.rpc("submit_parking_space_for_review", {
      p_expected_version: draft.version,
      p_space_id: draft.id
    });

    if (error) {
      throw error;
    }

    await authService.ensureProfile();
    return data;
  }
};
