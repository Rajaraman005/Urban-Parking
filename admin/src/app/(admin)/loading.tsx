import { TableSkeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <div className="space-y-5">
      <div className="h-9 w-72 animate-pulse rounded-md bg-zinc-200" />
      <TableSkeleton />
    </div>
  );
}
