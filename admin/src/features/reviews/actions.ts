"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { assertSameOrigin } from "@/server/auth/http";
import { assertValidCsrfToken, requireAdmin } from "@/server/auth/session";
import { transitionListing } from "./repository";
import { formString, noteActionSchema, reasonActionSchema, reviewActionSchema } from "./validation";

async function authorize(formData: FormData) {
  await assertSameOrigin();
  const session = await requireAdmin();
  await assertValidCsrfToken(formString(formData, "csrfToken"));
  return session;
}

function revalidateListing(id: string) {
  revalidatePath("/reviews");
  revalidatePath("/approved");
  revalidatePath("/rejected");
  revalidatePath(`/reviews/${id}`);
}

export async function approveListingAction(formData: FormData) {
  const session = await authorize(formData);
  const input = reviewActionSchema.parse({
    csrfToken: formString(formData, "csrfToken"),
    listingId: formString(formData, "listingId")
  });
  await transitionListing({ action: "approve", adminUserId: session.admin.id, listingId: input.listingId });
  revalidateListing(input.listingId);
  redirect(`/reviews/${input.listingId}?toast=approved`);
}

export async function rejectListingAction(formData: FormData) {
  const session = await authorize(formData);
  const input = reasonActionSchema.parse({
    csrfToken: formString(formData, "csrfToken"),
    listingId: formString(formData, "listingId"),
    reason: formString(formData, "reason")
  });
  await transitionListing({
    action: "reject",
    adminUserId: session.admin.id,
    listingId: input.listingId,
    reason: input.reason
  });
  revalidateListing(input.listingId);
  redirect(`/reviews/${input.listingId}?toast=rejected`);
}

export async function suspendListingAction(formData: FormData) {
  const session = await authorize(formData);
  const input = reasonActionSchema.parse({
    csrfToken: formString(formData, "csrfToken"),
    listingId: formString(formData, "listingId"),
    reason: formString(formData, "reason")
  });
  await transitionListing({
    action: "suspend",
    adminUserId: session.admin.id,
    listingId: input.listingId,
    reason: input.reason
  });
  revalidateListing(input.listingId);
  redirect(`/reviews/${input.listingId}?toast=suspended`);
}

export async function addReviewNoteAction(formData: FormData) {
  const session = await authorize(formData);
  const input = noteActionSchema.parse({
    csrfToken: formString(formData, "csrfToken"),
    internalNote: formString(formData, "internalNote"),
    listingId: formString(formData, "listingId")
  });
  await transitionListing({
    action: "note",
    adminUserId: session.admin.id,
    internalNote: input.internalNote,
    listingId: input.listingId
  });
  revalidateListing(input.listingId);
  redirect(`/reviews/${input.listingId}?toast=note`);
}

export async function softDeleteListingAction(formData: FormData) {
  const session = await authorize(formData);
  const input = noteActionSchema.parse({
    csrfToken: formString(formData, "csrfToken"),
    internalNote: formString(formData, "internalNote"),
    listingId: formString(formData, "listingId")
  });
  await transitionListing({
    action: "soft_delete",
    adminUserId: session.admin.id,
    internalNote: input.internalNote,
    listingId: input.listingId
  });
  revalidateListing(input.listingId);
  redirect("/reviews?toast=deleted");
}
