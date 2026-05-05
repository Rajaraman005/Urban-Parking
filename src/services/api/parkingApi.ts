import { MOCK_PARKING_SPOTS } from "@/constants/mockParking";
import { isSupabaseConfigured, supabase } from "@/lib/supabase/client";
import type { BookingQuote, GeoPoint, ParkingSpot } from "@/models/parking";
import { apiClient } from "@/services/api/apiClient";

export interface SearchParkingParams {
  center: GeoPoint;
  radiusKm: number;
  cadence?: ParkingSpot["cadence"];
}

type ParkingSpotApi = Partial<ParkingSpot> & {
  amenities?: unknown;
  cadence?: unknown;
  hourlyPrice?: unknown;
  imageUrl?: unknown;
  imageUrls?: unknown;
  image_url?: unknown;
  image_urls?: unknown;
  images?: unknown;
  parkingPhotos?: unknown;
  parking_space_photos?: unknown;
  photos?: unknown;
  price?: unknown;
};

const FALLBACK_IMAGE_URL =
  "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";

const isParkingCadence = (
  value: unknown,
): value is ParkingSpot["cadence"] =>
  value === "hourly" || value === "daily" || value === "monthly";

const isParkingAmenity = (
  value: unknown,
): value is ParkingSpot["amenities"][number] =>
  value === "covered" ||
  value === "security" ||
  value === "evCharging" ||
  value === "cctv" ||
  value === "valet" ||
  value === "twoWheeler";

const toNumber = (value: unknown, fallback: number) => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }

  return fallback;
};

const collectImageUrls = (payload: ParkingSpotApi) => {
  const urls = new Set<string>();

  const addUrl = (value: unknown) => {
    if (!value) return;

    if (typeof value === "string") {
      const url = value.trim();
      if (url) urls.add(url);
      return;
    }

    if (Array.isArray(value)) {
      for (const entry of value) addUrl(entry);
      return;
    }

    if (typeof value === "object") {
      const record = value as Record<string, unknown>;
      addUrl(record.secure_url);
      addUrl(record.secureUrl);
      addUrl(record.imageUrl);
      addUrl(record.image_url);
      addUrl(record.url);
      addUrl(record.src);
    }
  };

  addUrl(payload.imageUrls);
  addUrl(payload.image_urls);
  addUrl(payload.images);
  addUrl(payload.photos);
  addUrl(payload.parkingPhotos);
  addUrl(payload.parking_space_photos);
  addUrl(payload.imageUrl);
  addUrl(payload.image_url);

  if (urls.size === 0) {
    urls.add(FALLBACK_IMAGE_URL);
  }

  return [...urls];
};

const normalizeParkingSpot = (payload: ParkingSpotApi): ParkingSpot => {
  const imageUrls = collectImageUrls(payload);
  const imageUrl = imageUrls[0] ?? FALLBACK_IMAGE_URL;
  const amenities = Array.isArray(payload.amenities)
    ? payload.amenities.filter(isParkingAmenity)
    : [];
  const cadence = isParkingCadence(payload.cadence) ? payload.cadence : "hourly";

  return {
    address: typeof payload.address === "string" ? payload.address : "",
    amenities,
    availableFrom:
      typeof payload.availableFrom === "string"
        ? payload.availableFrom
        : new Date().toISOString(),
    availableUntil:
      typeof payload.availableUntil === "string"
        ? payload.availableUntil
        : new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString(),
    cadence,
    currency: payload.currency === "INR" ? "INR" : "INR",
    distanceKm: toNumber(payload.distanceKm, 0),
    id: typeof payload.id === "string" ? payload.id : "",
    imageUrl,
    imageUrls,
    locality: typeof payload.locality === "string" ? payload.locality : "",
    location:
      payload.location &&
      typeof payload.location === "object" &&
      typeof (payload.location as GeoPoint).latitude === "number" &&
      typeof (payload.location as GeoPoint).longitude === "number"
        ? (payload.location as GeoPoint)
        : { latitude: 13.0827, longitude: 80.2707 },
    price: Math.round(toNumber(payload.price, toNumber(payload.hourlyPrice, 0))),
    rating: toNumber(payload.rating, 0),
    reviewCount: Math.round(toNumber(payload.reviewCount, 0)),
    slotsAvailable: Math.round(toNumber(payload.slotsAvailable, 0)),
    title: typeof payload.title === "string" ? payload.title : "Parking space",
  };
};

const fetchSpotByPath = async (path: string, params?: Record<string, string>) => {
  const response = await apiClient.get<ParkingSpotApi>(path, { params });
  return normalizeParkingSpot(response.data);
};

const fetchSpotFromDatabase = async (id: string) => {
  const { data, error } = await supabase.rpc("get_public_parking_spot", {
    p_space_id: id,
  });

  if (error) {
    throw error;
  }

  if (!data || typeof data !== "object") {
    throw new Error("Parking spot not found");
  }

  return normalizeParkingSpot(data as ParkingSpotApi);
};

export const parkingApi = {
  async searchNearby(params: SearchParkingParams): Promise<ParkingSpot[]> {
    if (__DEV__) {
      return Promise.resolve(MOCK_PARKING_SPOTS.map(normalizeParkingSpot));
    }

    const response = await apiClient.get<ParkingSpot[]>("/parking-spots", { params });
    return response.data.map((spot) => normalizeParkingSpot(spot));
  },

  async getById(id: string): Promise<ParkingSpot> {
    if (__DEV__) {
      const spot = MOCK_PARKING_SPOTS.find((item) => item.id === id);

      if (!spot) {
        throw new Error("Parking spot not found");
      }

      return Promise.resolve(normalizeParkingSpot(spot));
    }

    if (isSupabaseConfigured) {
      try {
        return await fetchSpotFromDatabase(id);
      } catch {
        // Fall through to legacy API paths while deployments catch up.
      }
    }

    try {
      const spot = await fetchSpotByPath(`/parking-spots/${id}`);
      if (spot.imageUrls.length > 1) {
        return spot;
      }

      const upgradedSpot = await fetchSpotByPath("/parking-spots", { id });
      return upgradedSpot.imageUrls.length >= spot.imageUrls.length
        ? upgradedSpot
        : spot;
    } catch (error) {
      const upgradedSpot = await fetchSpotByPath("/parking-spots", { id });
      if (upgradedSpot.id) {
        return upgradedSpot;
      }
      throw error;
    }
  },

  async quoteBooking(spotId: string, startAt: string, endAt: string): Promise<BookingQuote> {
    if (__DEV__) {
      const spot = await this.getById(spotId);
      const subtotal = spot.price;
      const platformFee = Math.round(subtotal * 0.08);
      const taxes = Math.round((subtotal + platformFee) * 0.18);

      return {
        spotId,
        startAt,
        endAt,
        subtotal,
        platformFee,
        taxes,
        total: subtotal + platformFee + taxes,
        currency: "INR"
      };
    }

    const response = await apiClient.post<BookingQuote>("/bookings/quote", {
      spotId,
      startAt,
      endAt
    });

    return response.data;
  }
};
