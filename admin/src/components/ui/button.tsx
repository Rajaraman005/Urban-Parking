import { cn } from "@/lib/cn";

const variants = {
  danger: "bg-[#e5484d] text-white shadow-sm shadow-red-950/10 hover:bg-[#d92d37] focus-visible:outline-red-600",
  ghost: "bg-transparent text-zinc-600 hover:bg-zinc-100 hover:text-zinc-950 focus-visible:outline-zinc-500",
  primary: "bg-zinc-950 text-white shadow-sm shadow-zinc-950/15 hover:bg-zinc-800 focus-visible:outline-zinc-950",
  secondary:
    "border border-zinc-200 bg-white text-zinc-800 shadow-sm shadow-zinc-950/[0.03] hover:border-zinc-300 hover:bg-zinc-50 hover:text-zinc-950 focus-visible:outline-zinc-500",
  warning: "bg-[#c77700] text-white shadow-sm shadow-amber-950/10 hover:bg-[#ad6800] focus-visible:outline-amber-600"
};

export function buttonClassName({
  className,
  variant = "primary"
}: {
  className?: string;
  variant?: keyof typeof variants;
} = {}) {
  return cn(
    "inline-flex h-11 items-center justify-center gap-2 rounded-lg px-4 text-[15px] font-semibold transition duration-150 active:translate-y-px focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:pointer-events-none disabled:opacity-55",
    variants[variant],
    className
  );
}

export function Button({
  className,
  variant,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: keyof typeof variants }) {
  return <button className={buttonClassName({ className, variant })} {...props} />;
}
