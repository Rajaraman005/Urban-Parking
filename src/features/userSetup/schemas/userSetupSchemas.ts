import { z } from "zod";

import { getTodayDateKeyInIndia, TIME_SLOT_INTERVAL_MINUTES } from "@/features/userSetup/utils/availability";

const futureOrTodayDateKeySchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Use a valid calendar date")
  .refine((value) => value >= getTodayDateKeyInIndia(), "Choose today or a future date");

const optionalNumber = (schema: z.ZodType<number>) =>
  z.preprocess((value) => (value === "" || value === null || typeof value === "undefined" ? undefined : value), schema.optional());

const indiaLatitudeSchema = z
  .number({ error: "Confirm the map pin before continuing" })
  .finite("Confirm the map pin before continuing")
  .min(6, "Choose a location inside India")
  .max(38, "Choose a location inside India");
const indiaLongitudeSchema = z
  .number({ error: "Confirm the map pin before continuing" })
  .finite("Confirm the map pin before continuing")
  .min(68, "Choose a location inside India")
  .max(98, "Choose a location inside India");

export const availabilityRuleSchema = z.object({
  endMinute: z
    .number()
    .int()
    .min(TIME_SLOT_INTERVAL_MINUTES, "Choose an end time")
    .max(24 * 60, "End time is too late")
    .refine((value) => value % TIME_SLOT_INTERVAL_MINUTES === 0, "Use 30-minute time slots"),
  startMinute: z
    .number()
    .int()
    .min(0, "Choose a start time")
    .max(24 * 60 - TIME_SLOT_INTERVAL_MINUTES, "Start time is too late")
    .refine((value) => value % TIME_SLOT_INTERVAL_MINUTES === 0, "Use 30-minute time slots"),
  weekday: z.number().int().min(0).max(6)
});

export const phoneSchema = z
  .string()
  .trim()
  .regex(/^[6-9]\d{9}$/, "Enter a valid 10-digit Indian mobile number");

export const intentSchema = z.object({
  intent: z.enum(["park", "host"])
});

export const profileSetupSchema = z.object({
  fullName: z.string().trim().min(2, "Enter your full name").max(80, "Name is too long"),
  phone: phoneSchema,
  gender: z.enum(["male", "female", "other", "prefer_not_to_say"], {
    error: "Please select a gender"
  }),
  dob: z
    .string()
    .min(1, "Enter your date of birth")
    .trim()
    .regex(/^(0[1-9]|[12]\d|3[01])\/(0[1-9]|1[0-2])\/\d{4}$/, "Enter date as DD/MM/YYYY")
    .refine((val) => {
      const [day, month, year] = val.split("/").map(Number);
      if (!day || !month || !year) return false;
      const date = new Date(year, month - 1, day);
      return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day;
    }, "Enter a valid calendar date")
    .refine((val) => {
      const [day, month, year] = val.split("/").map(Number);
      if (!day || !month || !year) return false;
      const date = new Date(year, month - 1, day);
      const age = new Date().getFullYear() - date.getFullYear();
      return age >= 18;
    }, "You must be at least 18 years old")
});

export const hostBasicsSchema = z.object({
  accessInstructions: z.string().trim().max(240, "Instructions are too long").optional(),
  address: z.string().trim().min(8, "Enter the full address").max(220, "Address is too long"),
  addressConfidence: z.number().min(0).max(1),
  addressPlaceId: z.string().nullable(),
  addressProvider: z.enum(["nominatim", "manual"]),
  addressRawOsmJson: z.unknown().nullable(),
  city: z.string().trim().min(2, "Enter the city").max(80, "City is too long"),
  landmark: z.string().trim().min(2, "Enter building or house details").max(120, "Building details are too long"),
  latitude: indiaLatitudeSchema,
  locality: z.string().trim().min(2, "Enter the locality").max(80, "Locality is too long"),
  locationConfirmedAt: z.string().min(1, "Confirm the map pin before continuing"),
  longitude: indiaLongitudeSchema,
  parkingType: z.enum(["covered", "open", "garage", "driveway", "basement"]),
  postalCode: z.string().trim().regex(/^[1-9]\d{5}$/, "Enter a valid 6-digit Indian postal code"),
  vehicleFit: z.enum(["bike", "car", "both"])
});

export const hostLocationSchema = z.object({
  address: z.string().trim().max(220, "Address is too long").optional(),
  addressConfidence: z.number().min(0).max(1),
  addressPlaceId: z.string().nullable(),
  addressProvider: z.enum(["nominatim", "manual"]),
  addressRawOsmJson: z.unknown().nullable(),
  city: z.string().trim().max(80, "City is too long").optional(),
  latitude: indiaLatitudeSchema,
  locality: z.string().trim().max(80, "Locality is too long").optional(),
  locationConfirmedAt: z.string().min(1, "Confirm the map pin before continuing"),
  longitude: indiaLongitudeSchema,
  postalCode: z.string().trim().regex(/^[1-9]\d{5}$/, "Enter a valid 6-digit Indian postal code").optional()
});

export const hostPricingSchema = z
  .object({
    availableFromDate: futureOrTodayDateKeySchema,
    availableToDate: futureOrTodayDateKeySchema,
    dailyEndMinute: z
      .number()
      .int()
      .min(TIME_SLOT_INTERVAL_MINUTES, "Choose an end time")
      .max(24 * 60, "End time is too late")
      .refine((value) => value % TIME_SLOT_INTERVAL_MINUTES === 0, "Use 30-minute time slots"),
    dailyStartMinute: z
      .number()
      .int()
      .min(0, "Choose a start time")
      .max(24 * 60 - TIME_SLOT_INTERVAL_MINUTES, "Start time is too late")
      .refine((value) => value % TIME_SLOT_INTERVAL_MINUTES === 0, "Use 30-minute time slots"),
    heightFeet: optionalNumber(z.coerce.number().min(0, "Height cannot be negative").max(30, "Height looks too high")),
    hourlyPrice: z.coerce
      .number()
      .int("Enter a whole rupee amount")
      .min(10, "Minimum hourly price is Rs 10")
      .max(10000, "Price is too high"),
    lengthFeet: z.coerce.number().min(4, "Length is too small").max(80, "Length looks too large"),
    skipWeekends: z.boolean(),
    slotsCount: z.coerce.number().int("Enter a whole number").min(1, "At least 1 slot is required").max(50, "Too many slots for setup"),
    widthFeet: z.coerce.number().min(3, "Width is too small").max(40, "Width looks too large")
  })
  .superRefine((values, context) => {
    if (values.availableToDate < values.availableFromDate) {
      context.addIssue({
        code: "custom",
        message: "End date must be on or after the start date",
        path: ["availableToDate"]
      });
    }

    if (values.dailyEndMinute <= values.dailyStartMinute) {
      context.addIssue({
        code: "custom",
        message: "End time must be after start time",
        path: ["dailyEndMinute"]
      });
    }
  });

export type IntentFormValues = z.infer<typeof intentSchema>;
export type ProfileSetupValues = z.infer<typeof profileSetupSchema>;
export type HostBasicsValues = z.infer<typeof hostBasicsSchema>;
export type HostLocationValues = z.infer<typeof hostLocationSchema>;
export type AvailabilityRuleValues = z.infer<typeof availabilityRuleSchema>;
export type HostPricingFormInput = z.input<typeof hostPricingSchema>;
export type HostPricingValues = z.infer<typeof hostPricingSchema>;
