"use client";

import { useEffect, useState } from "react";
import { CheckCircle2, Info, TriangleAlert } from "lucide-react";
import { cn } from "@/lib/cn";

const messages: Record<string, { tone: "success" | "warning" | "info"; text: string }> = {
  approved: { tone: "success", text: "Listing approved and made visible." },
  deleted: { tone: "warning", text: "Listing was soft deleted." },
  note: { tone: "info", text: "Internal note added." },
  password: { tone: "success", text: "Password updated." },
  rejected: { tone: "warning", text: "Listing rejected and kept hidden." },
  sessions: { tone: "success", text: "Other sessions revoked." },
  suspended: { tone: "warning", text: "Listing suspended and hidden." }
};

const toneClass = {
  info: "border-blue-200 bg-blue-50 text-blue-950",
  success: "border-emerald-200 bg-emerald-50 text-emerald-950",
  warning: "border-amber-200 bg-amber-50 text-amber-950"
};

export function Toast({ value }: { value?: string }) {
  const config = value ? messages[value] : undefined;
  const [dismissedValue, setDismissedValue] = useState<string | undefined>();
  const visible = Boolean(config && dismissedValue !== value);

  useEffect(() => {
    if (!config || !value) return;
    const timeout = window.setTimeout(() => setDismissedValue(value), 4200);
    return () => window.clearTimeout(timeout);
  }, [config, value]);

  if (!config || !visible) return null;
  const Icon = config.tone === "success" ? CheckCircle2 : config.tone === "warning" ? TriangleAlert : Info;

  return (
    <div
      className={cn(
        "fixed right-5 top-5 z-50 flex max-w-sm items-center gap-3 rounded-lg border px-4 py-3 text-sm font-semibold shadow-lg",
        toneClass[config.tone]
      )}
      role="status"
    >
      <Icon className="h-4 w-4 shrink-0" />
      <span>{config.text}</span>
    </div>
  );
}
