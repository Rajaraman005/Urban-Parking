import { handleMarkConversationRead } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "conversation-read", limit: 240, windowSeconds: 60 },
    route: "/api/v1/conversations/[id]/read",
  },
  handleMarkConversationRead,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "conversation-read-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/conversations/[id]/read",
  },
  handleMarkConversationRead,
);
