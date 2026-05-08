import { handleGeoDiscoverySearch } from "@/server/mobile-api/geo-discovery";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "geo-discovery", limit: 60, windowSeconds: 60 },
    route: "/api/v1/geo-discovery/search",
  },
  handleGeoDiscoverySearch,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "geo-discovery", limit: 60, windowSeconds: 60 },
    route: "/api/v1/geo-discovery/search",
  },
  handleGeoDiscoverySearch,
);

export const GET = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "geo-discovery", limit: 60, windowSeconds: 60 },
    route: "/api/v1/geo-discovery/search",
  },
  handleGeoDiscoverySearch,
);
