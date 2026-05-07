"use client";

import { useFormStatus } from "react-dom";
import { buttonClassName } from "./button";

export function SubmitButton({
  children,
  className,
  pendingLabel = "Saving...",
  variant = "primary"
}: {
  children: React.ReactNode;
  className?: string;
  pendingLabel?: string;
  variant?: "danger" | "ghost" | "primary" | "secondary" | "warning";
}) {
  const { pending } = useFormStatus();
  return (
    <button disabled={pending} className={buttonClassName({ className, variant })} type="submit">
      {pending ? pendingLabel : children}
    </button>
  );
}
