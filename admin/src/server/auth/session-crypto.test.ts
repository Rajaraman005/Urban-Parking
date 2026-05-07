import { describe, expect, it } from "vitest";
import { csrfTokenForSession, generateOpaqueToken, ipHash, safeEqual, sha256Hex } from "./session-crypto";

describe("admin session crypto", () => {
  it("generates opaque high-entropy tokens", () => {
    const left = generateOpaqueToken();
    const right = generateOpaqueToken();
    expect(left).not.toEqual(right);
    expect(left.length).toBeGreaterThanOrEqual(40);
  });

  it("hashes session tokens without preserving raw token material", () => {
    const token = "raw-session-token";
    const digest = sha256Hex(token);
    expect(digest).toHaveLength(64);
    expect(digest).not.toContain(token);
  });

  it("derives stable csrf and ip hashes from the server secret", () => {
    const secret = "a".repeat(32);
    expect(csrfTokenForSession("session", secret)).toEqual(csrfTokenForSession("session", secret));
    expect(ipHash("127.0.0.1", secret)).toHaveLength(64);
    expect(safeEqual("abc", "abc")).toBe(true);
    expect(safeEqual("abc", "abd")).toBe(false);
  });
});
