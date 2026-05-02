import { MOCK_PARKING_SPOTS } from "@/constants/mockParking";
import type { BookingQuote, GeoPoint, ParkingSpot } from "@/models/parking";
import { apiClient } from "@/services/api/apiClient";

export interface SearchParkingParams {
  center: GeoPoint;
  radiusKm: number;
  cadence?: ParkingSpot["cadence"];
}

export const parkingApi = {
  async searchNearby(params: SearchParkingParams): Promise<ParkingSpot[]> {
    if (__DEV__) {
      return Promise.resolve(MOCK_PARKING_SPOTS);
    }

    const response = await apiClient.get<ParkingSpot[]>("/parking-spots", { params });
    return response.data;
  },

  async getById(id: string): Promise<ParkingSpot> {
    if (__DEV__) {
      const spot = MOCK_PARKING_SPOTS.find((item) => item.id === id);

      if (!spot) {
        throw new Error("Parking spot not found");
      }

      return Promise.resolve(spot);
    }

    const response = await apiClient.get<ParkingSpot>(`/parking-spots/${id}`);
    return response.data;
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
