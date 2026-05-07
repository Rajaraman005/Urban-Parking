"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { Check, FileText, PauseCircle, Trash2, X } from "lucide-react";
import { Button, buttonClassName } from "@/components/ui/button";
import { SubmitButton } from "@/components/ui/submit-button";
import {
  addReviewNoteAction,
  approveListingAction,
  rejectListingAction,
  softDeleteListingAction,
  suspendListingAction
} from "./actions";
import type { AdminListingStatus } from "./status";

type DialogKind = "approve" | "reject" | "suspend" | "note" | "delete" | null;

export function ReviewActionPanel({
  csrfToken,
  deletedAt,
  listingId,
  status
}: {
  csrfToken: string;
  deletedAt?: string;
  listingId: string;
  status: AdminListingStatus;
}) {
  const [dialog, setDialog] = useState<DialogKind>(null);
  const canApprove = !deletedAt && ["pending", "rejected", "suspended"].includes(status);
  const canReject = !deletedAt && status === "pending";
  const canSuspend = !deletedAt && status === "approved";
  const canMutate = !deletedAt;

  return (
    <div className="rounded-lg border border-zinc-200/80 bg-white p-5 shadow-[0_1px_2px_rgba(16,24,40,0.06)]">
      <h2 className="text-base font-semibold text-zinc-950">Actions</h2>
      <div className="mt-4 grid gap-2.5 sm:grid-cols-2 lg:grid-cols-1">
        {canApprove ? (
          <Button onClick={() => setDialog("approve")}>
            <Check className="h-4 w-4" />
            Approve
          </Button>
        ) : null}
        {canReject ? (
          <Button onClick={() => setDialog("reject")} variant="danger">
            <X className="h-4 w-4" />
            Reject
          </Button>
        ) : null}
        {canSuspend ? (
          <Button onClick={() => setDialog("suspend")} variant="warning">
            <PauseCircle className="h-4 w-4" />
            Suspend
          </Button>
        ) : null}
        {canMutate ? (
          <>
            <Button onClick={() => setDialog("note")} variant="secondary">
              <FileText className="h-4 w-4" />
              Add note
            </Button>
            <Button onClick={() => setDialog("delete")} variant="secondary">
              <Trash2 className="h-4 w-4" />
              Soft delete
            </Button>
          </>
        ) : (
          <div className="rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-sm text-zinc-500">This listing has been deleted.</div>
        )}
      </div>
      <ActionDialog
        csrfToken={csrfToken}
        dialog={dialog}
        listingId={listingId}
        onClose={() => setDialog(null)}
      />
    </div>
  );
}

function ActionDialog({
  csrfToken,
  dialog,
  listingId,
  onClose
}: {
  csrfToken: string;
  dialog: DialogKind;
  listingId: string;
  onClose: () => void;
}) {
  useEffect(() => {
    if (!dialog) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [dialog]);

  if (!dialog) return null;

  const config = {
    approve: {
      action: approveListingAction,
      body: "This listing will become visible to renters.",
      submit: "Approve listing",
      title: "Approve listing?"
    },
    delete: {
      action: softDeleteListingAction,
      body: "The row stays in the database for audit history and is hidden from all public queries.",
      submit: "Soft delete",
      title: "Soft delete listing?"
    },
    note: {
      action: addReviewNoteAction,
      body: "Internal notes are visible only to admins.",
      submit: "Add note",
      title: "Add internal note"
    },
    reject: {
      action: rejectListingAction,
      body: "The host-facing reason should be clear and actionable.",
      submit: "Reject listing",
      title: "Reject listing?"
    },
    suspend: {
      action: suspendListingAction,
      body: "The approved listing will be hidden until it is approved again.",
      submit: "Suspend listing",
      title: "Suspend listing?"
    }
  }[dialog];

  const needsReason = dialog === "reject" || dialog === "suspend";
  const needsNote = dialog === "note" || dialog === "delete";

  if (typeof document === "undefined") return null;

  return createPortal(
    <div
      className="fixed inset-0 z-[100] grid place-items-center bg-black/40 px-4 backdrop-blur-[2px]"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
      role="presentation"
    >
      <div
        aria-modal="true"
        className="w-full max-w-md rounded-lg border border-zinc-200/80 bg-white p-6 shadow-2xl shadow-zinc-950/15"
        onMouseDown={(event) => event.stopPropagation()}
        role="dialog"
      >
        <h3 className="text-xl font-semibold text-zinc-950">{config.title}</h3>
        <p className="mt-2 text-sm leading-6 text-zinc-600">{config.body}</p>
        <form action={config.action} className="mt-4 space-y-4">
          <input name="csrfToken" type="hidden" value={csrfToken} />
          <input name="listingId" type="hidden" value={listingId} />
          {needsReason ? (
            <textarea
              className="min-h-28 w-full rounded-lg border border-zinc-200 px-3 py-2 text-sm outline-none transition focus:border-zinc-500 focus:ring-4 focus:ring-zinc-100"
              name="reason"
              placeholder="Reason"
              required
            />
          ) : null}
          {needsNote ? (
            <textarea
              className="min-h-28 w-full rounded-lg border border-zinc-200 px-3 py-2 text-sm outline-none transition focus:border-zinc-500 focus:ring-4 focus:ring-zinc-100"
              name="internalNote"
              placeholder="Internal note"
              required
            />
          ) : null}
          <div className="flex justify-end gap-2">
            <button className={buttonClassName({ variant: "ghost" })} onClick={onClose} type="button">
              Cancel
            </button>
            <SubmitButton pendingLabel="Working..." variant={dialog === "reject" ? "danger" : dialog === "suspend" ? "warning" : "primary"}>
              {config.submit}
            </SubmitButton>
          </div>
        </form>
      </div>
    </div>,
    document.body
  );
}
