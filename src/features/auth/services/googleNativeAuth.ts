import {
  GoogleSignin,
  isCancelledResponse,
  isErrorWithCode,
  statusCodes
} from "@react-native-google-signin/google-signin";
import { Platform } from "react-native";

import { env } from "@/config/env";
import { AppAuthError } from "@/features/auth/services/authErrors";
import { logger } from "@/utils/logger";

let hasConfiguredGoogle = false;

const assertGoogleConfigured = () => {
  if (!env.googleWebClientId) {
    throw new AppAuthError(
      "configuration",
      "Google sign-in is missing EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID.",
      "missing_google_web_client_id"
    );
  }
};

const configureGoogle = () => {
  if (hasConfiguredGoogle) {
    return;
  }

  assertGoogleConfigured();
  GoogleSignin.configure({
    scopes: ["email", "profile"],
    webClientId: env.googleWebClientId,
    iosClientId: env.googleIosClientId || undefined,
    offlineAccess: false
  });
  hasConfiguredGoogle = true;
};

const mapGoogleError = (error: unknown) => {
  if (!isErrorWithCode(error)) {
    return new AppAuthError("google_native_failed");
  }

  if (error.code === statusCodes.SIGN_IN_CANCELLED) {
    return new AppAuthError("google_native_failed", "Google sign-in was cancelled.", error.code);
  }

  if (error.code === statusCodes.PLAY_SERVICES_NOT_AVAILABLE) {
    return new AppAuthError("google_native_failed", "Google Play Services is unavailable or outdated.", error.code);
  }

  if (error.code === statusCodes.IN_PROGRESS) {
    return new AppAuthError("google_native_failed", "Google sign-in is already in progress.", error.code);
  }

  return new AppAuthError("google_native_failed", error.message, error.code);
};

export const googleNativeAuth = {
  async getGoogleTokens() {
    try {
      configureGoogle();

      if (Platform.OS === "android") {
        await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
      }

      const response = await GoogleSignin.signIn();

      if (isCancelledResponse(response)) {
        throw new AppAuthError("google_native_failed", "Google sign-in was cancelled.", "cancelled");
      }

      const tokens = await GoogleSignin.getTokens();
      const idToken = tokens.idToken || response.data.idToken;
      const accessToken = tokens.accessToken;

      if (!idToken) {
        throw new AppAuthError("google_token_exchange_failed", "Google did not return an identity token.", "missing_id_token");
      }

      if (!accessToken) {
        throw new AppAuthError("google_token_exchange_failed", "Google did not return an access token.", "missing_access_token");
      }

      logger.info("auth_event", { type: "google_native_token_acquired" });
      return { accessToken, idToken };
    } catch (error) {
      const mapped = error instanceof AppAuthError ? error : mapGoogleError(error);
      logger.warn("auth_error", { category: mapped.category, code: mapped.code });
      throw mapped;
    }
  },

  async signOutIfAvailable() {
    try {
      if (!hasConfiguredGoogle) {
        return;
      }

      await GoogleSignin.signOut();
    } catch (error) {
      logger.warn("auth_error", { category: "google_native_failed", code: isErrorWithCode(error) ? error.code : undefined });
    }
  }
};
