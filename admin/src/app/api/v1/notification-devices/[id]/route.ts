import { withMobileApi } from "@/server/mobile-api/core";
import { handleDeleteNotificationDevice } from "@/server/mobile-api/notifications";

export const runtime = "nodejs";

export const DELETE = withMobileApi(
  {
    methods: ["DELETE"],
    rateLimit: {
      bucket: "notification-device-delete",
      limit: 30,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-devices/[id]",
  },
  handleDeleteNotificationDevice,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["DELETE"],
    rateLimit: {
      bucket: "notification-device-delete-options",
      limit: 120,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-devices/[id]",
  },
  handleDeleteNotificationDevice,
);
