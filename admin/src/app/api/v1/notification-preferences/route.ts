import { withMobileApi } from "@/server/mobile-api/core";
import {
  handleGetNotificationPreferences,
  handlePatchNotificationPreferences,
} from "@/server/mobile-api/notifications";

export const runtime = "nodejs";

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: {
      bucket: "notification-preferences-get",
      limit: 120,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-preferences",
  },
  handleGetNotificationPreferences,
);

export const PATCH = withMobileApi(
  {
    methods: ["PATCH"],
    rateLimit: {
      bucket: "notification-preferences-patch",
      limit: 60,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-preferences",
  },
  handlePatchNotificationPreferences,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET", "PATCH"],
    rateLimit: {
      bucket: "notification-preferences-options",
      limit: 120,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-preferences",
  },
  handleGetNotificationPreferences,
);
