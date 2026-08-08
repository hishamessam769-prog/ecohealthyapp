import * as React from "react";
import { cn } from "@/lib/utils";

export function Input({ className, ...props }: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cn("min-h-11 w-full rounded-md border border-[#cfdad3] bg-white px-3 text-sm text-[#17211b] outline-none placeholder:text-[#97a199] focus:border-[#16794a] focus:ring-2 focus:ring-[#16794a]/10", className)} {...props} />;
}
