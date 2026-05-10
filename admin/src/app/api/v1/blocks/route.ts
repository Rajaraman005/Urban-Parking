import { handleBlockUser } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "block-user", limit: 30, windowSeconds: 60 },
    route: "/api/v1/blocks",
  },
  handleBlockUser,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "block-user-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/blocks",
  },
  handleBlockUser,
);
