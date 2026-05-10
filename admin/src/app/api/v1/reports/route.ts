import { handleReportMessage } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "report-message", limit: 30, windowSeconds: 60 },
    route: "/api/v1/reports",
  },
  handleReportMessage,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "report-message-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/reports",
  },
  handleReportMessage,
);
