import type { GeoFailureCode } from "@/types/geo";

export class GeoDiscoveryError extends Error {
  code: GeoFailureCode;
  retryAfterMs?: number;
  retryable: boolean;

  constructor(message: string, options: { code: GeoFailureCode; retryAfterMs?: number; retryable?: boolean }) {
    super(message);
    this.name = "GeoDiscoveryError";
    this.code = options.code;
    this.retryAfterMs = options.retryAfterMs;
    this.retryable = options.retryable ?? true;
  }
}

export const toGeoDiscoveryError = (error: unknown): GeoDiscoveryError => {
  if (error instanceof GeoDiscoveryError) {
    return error;
  }

  if (error instanceof Error && error.name === "AbortError") {
    return new GeoDiscoveryError("Geo discovery request was aborted", {
      code: "aborted",
      retryable: false
    });
  }

  if (error instanceof Error) {
    return new GeoDiscoveryError(error.message, {
      code: "network_error",
      retryable: true
    });
  }

  return new GeoDiscoveryError("Geo discovery failed", {
    code: "unknown",
    retryable: true
  });
};
