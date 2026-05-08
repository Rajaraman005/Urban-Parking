import { handleBookingQuote } from "@/server/mobile-api/booking-quote";
import { withMobileApi } from "@/server/mobile-api/core";

export const runtime = "nodejs";

export const POST = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-quote", limit: 30, windowSeconds: 60 },
    route: "/api/v1/bookings/quote",
  },
  handleBookingQuote,
);

export const OPTIONS = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-quote", limit: 30, windowSeconds: 60 },
    route: "/api/v1/bookings/quote",
  },
  handleBookingQuote,
);

export const GET = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "booking-quote", limit: 30, windowSeconds: 60 },
    route: "/api/v1/bookings/quote",
  },
  handleBookingQuote,
);
