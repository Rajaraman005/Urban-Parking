import { create } from "zustand";

import type { GeoDiscoveryBatchResult, GeoDiscoveryPage, ServiceType } from "@/types/geo";

interface GeoDiscoveryState {
  lastBatchResult: GeoDiscoveryBatchResult | null;
  pagesByFingerprint: Record<string, Partial<Record<ServiceType, GeoDiscoveryPage>>>;
  clear: () => void;
  setBatchResult: (result: GeoDiscoveryBatchResult) => void;
}

export const useGeoDiscoveryStore = create<GeoDiscoveryState>((set) => ({
  lastBatchResult: null,
  pagesByFingerprint: {},
  clear: () => set({ lastBatchResult: null, pagesByFingerprint: {} }),
  setBatchResult: (result) =>
    set((state) => ({
      lastBatchResult: result,
      pagesByFingerprint: {
        ...state.pagesByFingerprint,
        [result.queryFingerprint]: result.results
      }
    }))
}));
