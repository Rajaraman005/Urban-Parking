import { handleApproveBooking } from "@/server/mobile-api/bookings";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-approve", limit: 60, windowSeconds: 60 },
    route: "/api/v1/bookings/[id]/approve",
  },
  handleApproveBooking,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-approve", limit: 60, windowSeconds: 60 },
    route: "/api/v1/bookings/[id]/approve",
  },
  handleApproveBooking,
);

export const GET = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-approve", limit: 60, windowSeconds: 60 },
    route: "/api/v1/bookings/[id]/approve",
  },
  handleApproveBooking,
);
