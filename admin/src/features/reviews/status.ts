export type AdminListingStatus = "pending" | "approved" | "rejected" | "suspended";
export type DatabaseListingStatus = "pending_review" | "active" | "rejected" | "suspended";

export const statusLabel: Record<AdminListingStatus, string> = {
  approved: "Approved",
  pending: "Pending",
  rejected: "Rejected",
  suspended: "Suspended"
};

export const statusTone: Record<AdminListingStatus, "blue" | "green" | "red" | "amber"> = {
  approved: "green",
  pending: "blue",
  rejected: "red",
  suspended: "amber"
};

export function dbStatusForAdmin(status: AdminListingStatus): DatabaseListingStatus {
  switch (status) {
    case "approved":
      return "active";
    case "pending":
      return "pending_review";
    case "rejected":
      return "rejected";
    case "suspended":
      return "suspended";
  }
}

export function adminStatusForDb(status: string): AdminListingStatus {
  switch (status) {
    case "active":
      return "approved";
    case "rejected":
      return "rejected";
    case "suspended":
      return "suspended";
    case "pending_review":
    default:
      return "pending";
  }
}

export function statusDescription(status: AdminListingStatus) {
  switch (status) {
    case "approved":
      return "Visible to renters in the app";
    case "pending":
      return "Waiting for manual review";
    case "rejected":
      return "Hidden from renters with feedback";
    case "suspended":
      return "Hidden after previously being approved";
  }
}
