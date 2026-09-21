"use client";

import { FileDown, Printer } from "lucide-react";
import { Button } from "@/components/ui/button";

export function PrintInvoiceButton() {
  return <Button type="button" onClick={() => window.print()}><Printer size={17} /><FileDown size={16} />طباعة / حفظ PDF</Button>;
}
