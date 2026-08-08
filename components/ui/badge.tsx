import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva("inline-flex min-h-7 items-center rounded-md px-2.5 text-xs font-semibold", {
  variants: {
    variant: {
      default: "bg-[#e5f5ec] text-[#0f603a]",
      blue: "bg-blue-50 text-blue-700",
      orange: "bg-orange-50 text-orange-800",
      red: "bg-red-50 text-red-700",
      gray: "bg-slate-100 text-slate-700"
    }
  },
  defaultVariants: { variant: "default" }
});

export function Badge({ className, variant, ...props }: React.HTMLAttributes<HTMLSpanElement> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}
