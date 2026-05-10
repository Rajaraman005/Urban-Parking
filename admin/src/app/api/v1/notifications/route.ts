import {
  handleListNotifications,
  handleMarkNotificationsRead,
} from "@/server/mobile-api/notifications";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "notification-list", limit: 120, windowSeconds: 60 },
    route: "/api/v1/notifications",
  },
  handleListNotifications,
);

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "notification-read", limit: 120, windowSeconds: 60 },
    route: "/api/v1/notifications",
  },
  handleMarkNotificationsRead,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET", "POST"],
    rateLimit: { bucket: "notification-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/notifications",
  },
  handleListNotifications,
);
