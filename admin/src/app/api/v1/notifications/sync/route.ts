import { withMobileApi } from "@/server/mobile-api/core";
import { handleSyncNotifications } from "@/server/mobile-api/notifications";

export const runtime = "nodejs";

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "notification-sync", limit: 180, windowSeconds: 60 },
    route: "/api/v1/notifications/sync",
  },
  handleSyncNotifications,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: {
      bucket: "notification-sync-options",
      limit: 120,
      windowSeconds: 60,
    },
    route: "/api/v1/notifications/sync",
  },
  handleSyncNotifications,
);
