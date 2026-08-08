"use client";

import { HelpCircle } from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";

export function HelpTip({ text }: { text: string }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span role="note" tabIndex={0} className="inline-flex size-8 shrink-0 cursor-help items-center justify-center rounded-md text-[#6d7971] hover:bg-[#e9f1ec] hover:text-[#16794a]" aria-label="مساعدة">
          <HelpCircle size={17} />
        </span>
      </TooltipTrigger>
      <TooltipContent>{text}</TooltipContent>
    </Tooltip>
  );
}
