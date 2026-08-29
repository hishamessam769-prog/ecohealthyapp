import { describe,expect,it } from "vitest";
import fc from "fast-check";
import { calculateInvoice } from "@/lib/decimal";

describe("authoritative decimal calculations",()=>{
  it("does not use binary floating point for invoice totals",()=>expect(calculateInvoice({lines:[{quantity:"3",unitPrice:"0.10",discount:"0",taxRate:"0"}],deliveryFees:"0"}).total).toBe("0.30"));
  it("allocations preserve the exact cent total",()=>fc.assert(fc.property(fc.integer({min:1,max:1_000_000}),fc.integer({min:1,max:50}),(cents,parts)=>{const base=Math.floor(cents/parts);const remainder=cents%parts;const allocated=Array.from({length:parts},(_,i)=>base+(i<remainder?1:0));expect(allocated.reduce((a,b)=>a+b,0)).toBe(cents)})));
});

