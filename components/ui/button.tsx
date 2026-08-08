import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex min-h-11 items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#16794a]/35 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-[#16794a] text-white hover:bg-[#0f603a]",
        secondary: "bg-[#e8f2ec] text-[#145f3c] hover:bg-[#dbece2]",
        outline: "border border-[#cfdad3] bg-white text-[#34433a] hover:bg-[#f4f7f5]",
        destructive: "bg-[#c53d3d] text-white hover:bg-[#a93434]",
        ghost: "text-[#536158] hover:bg-[#edf3ef] hover:text-[#17211b]"
      },
      size: {
        default: "px-4 py-2",
        sm: "min-h-9 px-3 text-xs",
        lg: "min-h-12 px-5 text-base",
        icon: "size-11 p-0"
      }
    },
    defaultVariants: { variant: "default", size: "default" }
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export function Button({ className, variant, size, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}

export { buttonVariants };
