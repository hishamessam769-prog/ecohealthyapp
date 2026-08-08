import * as React from "react";
import { cn } from "@/lib/utils";

export function Textarea({ className, ...props }: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={cn("min-h-24 w-full resize-y rounded-md border border-[#cfdad3] bg-white px-3 py-2 text-sm text-[#17211b] outline-none placeholder:text-[#97a199] focus:border-[#16794a] focus:ring-2 focus:ring-[#16794a]/10", className)} {...props} />;
}
