import { ReviewIndexPage } from "@/features/reviews/review-index-page";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function ReviewsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  return (
    <ReviewIndexPage
      basePath="/reviews"
      page={single(params.page)}
      search={single(params.q)}
      status="pending"
      toast={single(params.toast)}
    />
  );
}

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}
