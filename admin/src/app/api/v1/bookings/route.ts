import {
  handleCreateBooking,
  handleListBookings,
} from "@/server/mobile-api/bookings";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-create-ip", limit: 60, windowSeconds: 60 },
    route: "/api/v1/bookings",
  },
  handleCreateBooking,
);

export const GET = withMobileApi(
  {
    methods: ["GET"],
    rateLimit: { bucket: "booking-list", limit: 120, windowSeconds: 60 },
    route: "/api/v1/bookings",
  },
  handleListBookings,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["GET", "POST"],
    rateLimit: { bucket: "booking-options", limit: 120, windowSeconds: 60 },
    route: "/api/v1/bookings",
  },
  handleListBookings,
);
