import { handleStartConversation } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "conversation-start", limit: 60, windowSeconds: 60 },
    route: "/api/v1/conversations/start",
  },
  handleStartConversation,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "conversation-start-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/conversations/start",
  },
  handleStartConversation,
);
