import { z } from "zod";

export const listingIdSchema = z.string().uuid();

export const reviewActionSchema = z.object({
  csrfToken: z.string().min(20),
  listingId: listingIdSchema
});

export const reasonActionSchema = reviewActionSchema.extend({
  reason: z.string().trim().min(4, "A reason is required.").max(1000)
});

export const noteActionSchema = reviewActionSchema.extend({
  internalNote: z.string().trim().min(2, "A note is required.").max(2000)
});

export function formString(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}
