import {
  handleListMessages,
  handleSendMessage,
} from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "message-list", limit: 180, windowSeconds: 60 },
    route: "/api/v1/conversations/[id]/messages",
  },
  handleListMessages,
);

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "message-send", limit: 120, windowSeconds: 60 },
    route: "/api/v1/conversations/[id]/messages",
  },
  handleSendMessage,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET", "POST"],
    rateLimit: { bucket: "message-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/conversations/[id]/messages",
  },
  handleListMessages,
);
