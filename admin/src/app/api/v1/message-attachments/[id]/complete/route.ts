import { handleCompleteAttachmentUpload } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "message-attachment-complete", limit: 90, windowSeconds: 60 },
    route: "/api/v1/message-attachments/[id]/complete",
  },
  handleCompleteAttachmentUpload,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "message-attachment-complete-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/message-attachments/[id]/complete",
  },
  handleCompleteAttachmentUpload,
);
