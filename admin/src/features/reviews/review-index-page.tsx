import { Toast } from "@/components/ui/toast";
import { listReviewListings } from "./repository";
import { ReviewIndex } from "./listing-table";
import type { AdminListingStatus } from "./status";

export async function ReviewIndexPage({
  basePath,
  page,
  search,
  status,
  toast
}: {
  basePath: string;
  page?: string;
  search?: string;
  status: AdminListingStatus;
  toast?: string;
}) {
  const result = await listReviewListings({
    page: Number(page ?? "1"),
    search,
    status
  });

  return <ReviewIndex basePath={basePath} result={result} search={search} status={status} toast={<Toast value={toast} />} />;
}
