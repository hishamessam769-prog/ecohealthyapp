import { describe,expect,it } from "vitest";
import { createInvoiceSchema,deliveryEventSchema,verifyPaymentSchema } from "@/lib/validators";
describe("API v1 validation",()=>{
 it("rejects invoice without idempotency",()=>expect(createInvoiceSchema.safeParse({}).success).toBe(false));
 it("rejects invalid delivery transitions at the boundary",()=>expect(deliveryEventSchema.safeParse({event_type:"HACK"}).success).toBe(false));
 it("requires finance evidence fields",()=>expect(verifyPaymentSchema.safeParse({payment_id:crypto.randomUUID()}).success).toBe(false));
});

