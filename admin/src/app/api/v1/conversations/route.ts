import { handleListConversations } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "conversation-list", limit: 120, windowSeconds: 60 },
    route: "/api/v1/conversations",
  },
  handleListConversations,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "conversation-list-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/conversations",
  },
  handleListConversations,
);
