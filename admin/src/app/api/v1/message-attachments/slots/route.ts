import { handleCreateAttachmentSlot } from "@/server/mobile-api/messaging";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "message-attachment-slot", limit: 60, windowSeconds: 60 },
    route: "/api/v1/message-attachments/slots",
  },
  handleCreateAttachmentSlot,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "message-attachment-slot-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/message-attachments/slots",
  },
  handleCreateAttachmentSlot,
);
