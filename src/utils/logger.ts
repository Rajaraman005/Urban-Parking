type LogLevel = "debug" | "info" | "warn" | "error";

type SafeLogMeta = Record<string, string | number | boolean | null | undefined>;

const REDACTED_KEYS = [
  "password",
  "otp",
  "token",
  "access_token",
  "refresh_token",
  "authorization",
  "authorization_code"
];

const sanitizeMeta = (meta?: SafeLogMeta) => {
  if (!meta) {
    return undefined;
  }

  return Object.fromEntries(
    Object.entries(meta).map(([key, value]) => [
      key,
      REDACTED_KEYS.some((redactedKey) => key.toLowerCase().includes(redactedKey)) ? "[REDACTED]" : value
    ])
  );
};

const write = (level: LogLevel, event: string, meta?: SafeLogMeta) => {
  const payload = { event, ...sanitizeMeta(meta) };

  if (__DEV__) {
    const writer = level === "error" ? console.error : level === "warn" ? console.warn : console.log;
    writer(`[${level}]`, payload);
  }
};

export const logger = {
  debug: (event: string, meta?: SafeLogMeta) => write("debug", event, meta),
  info: (event: string, meta?: SafeLogMeta) => write("info", event, meta),
  warn: (event: string, meta?: SafeLogMeta) => write("warn", event, meta),
  error: (event: string, meta?: SafeLogMeta) => write("error", event, meta)
};
