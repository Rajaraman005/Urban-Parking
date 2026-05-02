import Constants from "expo-constants";

type AppEnv = "development" | "staging" | "production";

const extra = Constants.expoConfig?.extra ?? {};

export const env = {
  apiBaseUrl:
    process.env.EXPO_PUBLIC_API_BASE_URL ??
    (typeof extra.apiBaseUrl === "string" ? extra.apiBaseUrl : "https://api.urbanparking.local/v1"),
  appEnv:
    (process.env.EXPO_PUBLIC_APP_ENV ??
      (typeof extra.appEnv === "string" ? extra.appEnv : "development")) as AppEnv,
  requestTimeoutMs: 15000,
  supabaseUrl:
    process.env.EXPO_PUBLIC_SUPABASE_URL ??
    (typeof extra.supabaseUrl === "string" ? extra.supabaseUrl : ""),
  supabaseAnonKey:
    process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ??
    (typeof extra.supabaseAnonKey === "string" ? extra.supabaseAnonKey : ""),
  authRedirectScheme:
    process.env.EXPO_PUBLIC_AUTH_REDIRECT_SCHEME ??
    (typeof extra.authRedirectScheme === "string" ? extra.authRedirectScheme : "urbanparking"),
  googleWebClientId:
    process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID ??
    (typeof extra.googleWebClientId === "string" ? extra.googleWebClientId : ""),
  googleIosClientId:
    process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID ??
    (typeof extra.googleIosClientId === "string" ? extra.googleIosClientId : ""),
  cloudinaryCloudName:
    process.env.EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME ??
    (typeof extra.cloudinaryCloudName === "string" ? extra.cloudinaryCloudName : ""),
  cloudinaryUploadFolder:
    process.env.EXPO_PUBLIC_CLOUDINARY_UPLOAD_FOLDER ??
    (typeof extra.cloudinaryUploadFolder === "string"
      ? extra.cloudinaryUploadFolder
      : "urban-parking/listing-photos")
} as const;
