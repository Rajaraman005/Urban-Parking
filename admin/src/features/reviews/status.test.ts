import { describe, expect, it } from "vitest";
import { adminStatusForDb, dbStatusForAdmin } from "./status";

describe("review status mapping", () => {
  it("preserves Flutter-compatible database values", () => {
    expect(dbStatusForAdmin("pending")).toBe("pending_review");
    expect(dbStatusForAdmin("approved")).toBe("active");
    expect(dbStatusForAdmin("rejected")).toBe("rejected");
    expect(dbStatusForAdmin("suspended")).toBe("suspended");
  });

  it("maps database visibility states to admin labels", () => {
    expect(adminStatusForDb("pending_review")).toBe("pending");
    expect(adminStatusForDb("active")).toBe("approved");
    expect(adminStatusForDb("rejected")).toBe("rejected");
    expect(adminStatusForDb("suspended")).toBe("suspended");
  });
});
