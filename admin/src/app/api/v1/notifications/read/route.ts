import { withMobileApi } from "@/server/mobile-api/core";
import { handleMarkNotificationsRead } from "@/server/mobile-api/notifications";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "notification-read-v2", limit: 120, windowSeconds: 60 },
    route: "/api/v1/notifications/read",
  },
  handleMarkNotificationsRead,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: {
      bucket: "notification-read-v2-options",
      limit: 120,
      windowSeconds: 60,
    },
    route: "/api/v1/notifications/read",
  },
  handleMarkNotificationsRead,
);
