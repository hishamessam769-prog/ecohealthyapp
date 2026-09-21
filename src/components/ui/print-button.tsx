"use client";

import { Printer } from "lucide-react";
import { Button } from "@/components/ui/button";

export function PrintButton({ label = "طباعة / حفظ PDF" }: { label?: string }) {
  return <Button type="button" variant="secondary" onClick={() => window.print()}><Printer size={17} />{label}</Button>;
}
