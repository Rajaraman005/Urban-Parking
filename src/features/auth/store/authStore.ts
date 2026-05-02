import NetInfo from "@react-native-community/netinfo";
import type { AuthChangeEvent, Session, Subscription, User } from "@supabase/supabase-js";
import { create } from "zustand";

import { authService } from "@/features/auth/services/authService";
import { toAuthError } from "@/features/auth/services/authErrors";
import type { AuthCooldowns, AuthErrorState, AuthStatus, NetworkStatus } from "@/features/auth/types/auth.types";
import type { UserProfile } from "@/lib/supabase/database.types";
import { supabase } from "@/lib/supabase/client";
import { logger } from "@/utils/logger";

interface AuthStoreState {
  session: Session | null;
  user: User | null;
  profile: UserProfile | null;
  status: AuthStatus;
  networkStatus: NetworkStatus;
  sessionError: AuthErrorState | null;
  cooldowns: AuthCooldowns;
  hasCompletedOnboarding: boolean;
  hasInitialized: boolean;
  isHydrating: boolean;
  lastAuthEventId: string | null;
  completeOnboarding: () => void;
  getAccessToken: () => string | null;
  initializeAuth: () => Promise<void>;
  reloadProfile: () => Promise<UserProfile | null>;
  refreshSessionOrLogout: () => Promise<void>;
  setSessionFromAuthEvent: (event: AuthChangeEvent, session: Session | null) => Promise<void>;
  setCooldown: (key: keyof AuthCooldowns, until: number) => void;
  setNetworkStatus: (networkStatus: NetworkStatus) => void;
  signOut: () => Promise<void>;
}

let initializePromise: Promise<void> | null = null;
let authSubscription: Subscription | null = null;
let networkUnsubscribe: (() => void) | null = null;

const eventIdFor = (event: AuthChangeEvent, session: Session | null) =>
  `${event}:${session?.user.id ?? "anon"}:${session?.expires_at ?? "none"}`;

const clearAuthState = {
  session: null,
  user: null,
  profile: null
};

export const useAuthStore = create<AuthStoreState>((set, get) => ({
  ...clearAuthState,
  status: "idle",
  networkStatus: "unknown",
  sessionError: null,
  cooldowns: {},
  hasCompletedOnboarding: false,
  hasInitialized: false,
  isHydrating: false,
  lastAuthEventId: null,

  completeOnboarding: () => set({ hasCompletedOnboarding: true }),
  getAccessToken: () => get().session?.access_token ?? null,
  setNetworkStatus: (networkStatus) => set({ networkStatus }),
  setCooldown: (key, until) => set((state) => ({ cooldowns: { ...state.cooldowns, [key]: until } })),

  initializeAuth: async () => {
    if (initializePromise) {
      return initializePromise;
    }

    initializePromise = (async () => {
      const current = get();

      if (current.isHydrating || current.hasInitialized) {
        return;
      }

      set({ isHydrating: true, status: "hydrating", sessionError: null });

      try {
        if (!networkUnsubscribe) {
          networkUnsubscribe = NetInfo.addEventListener((state) => {
            const isOffline = state.isConnected === false || state.isInternetReachable === false;
            get().setNetworkStatus(isOffline ? "offline" : "online");
          });
        }

        if (!authSubscription) {
          const { data } = supabase.auth.onAuthStateChange((event, session) => {
            void get().setSessionFromAuthEvent(event, session);
          });
          authSubscription = data.subscription;
        }

        const session = await authService.getSession();

        if (!session) {
          set({ ...clearAuthState, status: "unauthenticated", hasInitialized: true, isHydrating: false });
          return;
        }

        const profile = await authService.ensureProfile();
        set({
          session,
          user: session.user,
          profile,
          status: "authenticated",
          sessionError: null,
          hasInitialized: true,
          isHydrating: false
        });
      } catch (error) {
        const mapped = toAuthError(error);
        logger.warn("auth_error", { category: mapped.category, code: mapped.code });
        set({
          ...clearAuthState,
          status: mapped.category === "session_expired" ? "expired" : "unauthenticated",
          sessionError: mapped,
          hasInitialized: true,
          isHydrating: false
        });
      } finally {
        initializePromise = null;
      }
    })();

    return initializePromise;
  },

  reloadProfile: async () => {
    const session = get().session ?? (await authService.getSession());

    if (!session) {
      set({ ...clearAuthState, status: "unauthenticated" });
      return null;
    }

    const profile = await authService.ensureProfile();
    set({
      session,
      user: session.user,
      profile,
      status: "authenticated",
      sessionError: null
    });

    return profile;
  },

  setSessionFromAuthEvent: async (event, session) => {
    const eventId = eventIdFor(event, session);

    if (get().lastAuthEventId === eventId) {
      return;
    }

    set({ lastAuthEventId: eventId });

    if (event === "SIGNED_OUT" || !session) {
      set({ ...clearAuthState, status: "unauthenticated" });
      return;
    }

    try {
      const profile = await authService.ensureProfile();
      set({
        session,
        user: session.user,
        profile,
        status: "authenticated",
        sessionError: null
      });
    } catch (error) {
      const mapped = toAuthError(error);
      logger.warn("profile_sync_failed", { category: mapped.category, code: mapped.code });
      set({
        session,
        user: session.user,
        profile: null,
        status: "authenticated",
        sessionError: mapped
      });
    }
  },

  refreshSessionOrLogout: async () => {
    try {
      const session = await authService.refreshSessionOrLogout();

      if (!session) {
        set({ ...clearAuthState, status: "expired", sessionError: { category: "session_expired", message: "Your session expired. Please log in again." } });
        return;
      }

      const profile = await authService.ensureProfile();
      set({ session, user: session.user, profile, status: "authenticated", sessionError: null });
    } catch (error) {
      const mapped = toAuthError(error);
      set({ ...clearAuthState, status: "expired", sessionError: mapped });
    }
  },

  signOut: async () => {
    try {
      await authService.signOut();
    } finally {
      set({ ...clearAuthState, status: "unauthenticated" });
    }
  }
}));
