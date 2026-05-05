export type BookingCadence = "hourly" | "daily" | "monthly";

export type ParkingAmenity =
  | "covered"
  | "security"
  | "evCharging"
  | "cctv"
  | "valet"
  | "twoWheeler";

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface ParkingSpot {
  id: string;
  title: string;
  address: string;
  locality: string;
  distanceKm: number;
  rating: number;
  reviewCount: number;
  price: number;
  currency: "INR";
  cadence: BookingCadence;
  availableFrom: string;
  availableUntil: string;
  slotsAvailable: number;
  location: GeoPoint;
  amenities: ParkingAmenity[];
  imageUrl: string;
  imageUrls: string[];
}

export interface BookingQuote {
  spotId: string;
  startAt: string;
  endAt: string;
  subtotal: number;
  platformFee: number;
  taxes: number;
  total: number;
  currency: "INR";
}
