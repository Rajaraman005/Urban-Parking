import { create } from "zustand";

import type { ParkingSpace, ParkingSpacePhoto } from "@/features/userSetup/types/userSetup.types";

interface UserSetupStoreState {
  draft: ParkingSpace | null;
  lastSavedAt: string | null;
  photos: ParkingSpacePhoto[];
  resetDraft: () => void;
  setDraft: (draft: ParkingSpace | null) => void;
  setPhotos: (photos: ParkingSpacePhoto[]) => void;
}

export const useUserSetupStore = create<UserSetupStoreState>((set) => ({
  draft: null,
  lastSavedAt: null,
  photos: [],
  resetDraft: () => set({ draft: null, lastSavedAt: null, photos: [] }),
  setDraft: (draft) => set({ draft, lastSavedAt: new Date().toISOString() }),
  setPhotos: (photos) => set({ photos })
}));
