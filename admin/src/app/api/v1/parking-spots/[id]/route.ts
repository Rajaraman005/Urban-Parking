import { withMobileApi } from "@/server/mobile-api/core";
import { handleParkingSpotByRoute } from "@/server/mobile-api/parking-spots";

export const runtime = "nodejs";

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "parking-detail", limit: 120, windowSeconds: 60 },
    route: "/api/v1/parking-spots/[id]",
  },
  handleParkingSpotByRoute,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "parking-detail", limit: 120, windowSeconds: 60 },
    route: "/api/v1/parking-spots/[id]",
  },
  handleParkingSpotByRoute,
);

export const POST = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "parking-detail", limit: 120, windowSeconds: 60 },
    route: "/api/v1/parking-spots/[id]",
  },
  handleParkingSpotByRoute,
);
