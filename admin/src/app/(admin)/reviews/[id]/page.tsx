import { notFound } from "next/navigation";
import { ReviewDetailView } from "@/features/reviews/detail-view";
import { getReviewDetail } from "@/features/reviews/repository";
import { csrfToken } from "@/server/auth/session";

type Params = Promise<{ id: string }>;
type SearchParams = Promise<Record<string, string | string[] | undefined>>;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export default async function ReviewDetailPage({
  params,
  searchParams
}: {
  params: Params;
  searchParams: SearchParams;
}) {
  const [{ id }, query] = await Promise.all([params, searchParams]);
  if (!UUID_PATTERN.test(id)) notFound();
  const [listing, token] = await Promise.all([getReviewDetail(id), csrfToken()]);
  if (!listing) notFound();
  return <ReviewDetailView csrfToken={token} listing={listing} toast={single(query.toast)} />;
}

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}
