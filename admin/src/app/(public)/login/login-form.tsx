"use client";

import { useActionState } from "react";
import { LockKeyhole, User } from "lucide-react";
import { loginAction, type LoginActionState } from "@/features/auth/actions";
import { SubmitButton } from "@/components/ui/submit-button";

const initialState: LoginActionState = {};

export function LoginForm() {
  const [state, formAction] = useActionState(loginAction, initialState);
  return (
    <form action={formAction} className="space-y-4">
      <div>
        <label className="text-sm font-semibold text-zinc-800" htmlFor="username">
          Username
        </label>
        <div className="mt-2 flex h-11 items-center gap-2 rounded-lg border border-zinc-200 bg-white px-3 transition focus-within:border-zinc-500 focus-within:ring-4 focus-within:ring-zinc-100">
          <User className="h-4 w-4 text-zinc-400" />
          <input
            autoComplete="username"
            className="h-full min-w-0 flex-1 border-0 bg-transparent text-sm font-medium outline-none placeholder:text-zinc-400"
            id="username"
            name="username"
            required
            type="text"
          />
        </div>
      </div>
      <div>
        <label className="text-sm font-semibold text-zinc-800" htmlFor="password">
          Password
        </label>
        <div className="mt-2 flex h-11 items-center gap-2 rounded-lg border border-zinc-200 bg-white px-3 transition focus-within:border-zinc-500 focus-within:ring-4 focus-within:ring-zinc-100">
          <LockKeyhole className="h-4 w-4 text-zinc-400" />
          <input
            autoComplete="current-password"
            className="h-full min-w-0 flex-1 border-0 bg-transparent text-sm font-medium outline-none placeholder:text-zinc-400"
            id="password"
            name="password"
            required
            type="password"
          />
        </div>
      </div>
      {state.error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm font-semibold text-red-800">
          {state.error}
        </div>
      ) : null}
      <SubmitButton className="w-full" pendingLabel="Signing in...">
        Sign in
      </SubmitButton>
    </form>
  );
}
