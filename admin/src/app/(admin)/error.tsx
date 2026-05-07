"use client";

import { ErrorState } from "@/components/ui/state-view";

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="space-y-4">
      <ErrorState body={error.message} />
      <button
        className="rounded-md border border-zinc-200 bg-white px-4 py-2 text-sm font-semibold text-zinc-900"
        onClick={() => reset()}
      >
        Try again
      </button>
    </div>
  );
}
