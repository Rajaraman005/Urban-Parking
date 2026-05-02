import { create } from "zustand";

import type { ParkingSpot } from "@/models/parking";

interface ParkingState {
  selectedSpotId: string | null;
  recentSpots: ParkingSpot[];
  selectSpot: (spotId: string | null) => void;
  setRecentSpots: (spots: ParkingSpot[]) => void;
}

export const useParkingStore = create<ParkingState>((set) => ({
  selectedSpotId: null,
  recentSpots: [],
  selectSpot: (selectedSpotId) => set({ selectedSpotId }),
  setRecentSpots: (recentSpots) => set({ recentSpots })
}));
