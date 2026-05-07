import { ReviewIndexPage } from "@/features/reviews/review-index-page";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function ApprovedPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  return (
    <ReviewIndexPage
      basePath="/approved"
      page={single(params.page)}
      search={single(params.q)}
      status="approved"
      toast={single(params.toast)}
    />
  );
}

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}
