import { withMobileApi } from "@/server/mobile-api/core";
import { handleRegisterNotificationDevice } from "@/server/mobile-api/notifications";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: {
      bucket: "notification-device-register",
      limit: 30,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-devices",
  },
  handleRegisterNotificationDevice,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: {
      bucket: "notification-device-options",
      limit: 120,
      windowSeconds: 60,
    },
    route: "/api/v1/notification-devices",
  },
  handleRegisterNotificationDevice,
);
