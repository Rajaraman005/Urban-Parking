import type { BookingCadence } from "@/models/parking";

export const formatMoney = (amount: number, currency = "INR") =>
  new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency,
    maximumFractionDigits: 0
  }).format(amount);

export const cadenceLabel = (cadence: BookingCadence) => {
  const labels: Record<BookingCadence, string> = {
    hourly: "hour",
    daily: "day",
    monthly: "month"
  };

  return labels[cadence];
};
