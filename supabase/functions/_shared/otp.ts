const textEncoder = new TextEncoder();

export const OTP_EXPIRY_MS = 5 * 60 * 1000;
export const OTP_MAX_FAILED_ATTEMPTS = 5;
export const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
export const OTP_USER_WINDOW_MS = 15 * 60 * 1000;
export const OTP_USER_WINDOW_LIMIT = 3;
export const OTP_DEVICE_WINDOW_LIMIT = 5;
export const OTP_IP_WINDOW_LIMIT = 10;

const toHex = (buffer: ArrayBuffer) =>
  Array.from(new Uint8Array(buffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

export const generateOtpCode = () => {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  const value = new DataView(bytes.buffer).getUint32(0) % 1_000_000;

  return value.toString().padStart(6, "0");
};

export const hashOtpCode = async (code: string, pepper: string) => {
  const digest = await crypto.subtle.digest("SHA-256", textEncoder.encode(`${code}.${pepper}`));

  return toHex(digest);
};

export const isSixDigitCode = (code: unknown): code is string =>
  typeof code === "string" && /^[0-9]{6}$/.test(code);

export const isDeviceFingerprint = (value: unknown): value is string =>
  typeof value === "string" && value.length >= 20 && value.length <= 120 && /^[a-zA-Z0-9_.:-]+$/.test(value);
