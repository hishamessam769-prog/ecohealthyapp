import { describe,expect,it } from "vitest";
import { assertNonOverlappingTiers,commissionAmount,evaluateMaturity } from "@/lib/commission";
const tiers=[{minPercentage:"0",maxPercentage:"60",ratePercentage:"0",fixedBonus:"0"},{minPercentage:"60",maxPercentage:"85",ratePercentage:"1.5",fixedBonus:"0"},{minPercentage:"85",maxPercentage:"100",ratePercentage:"1.75",fixedBonus:"0"},{minPercentage:"100",ratePercentage:"2",fixedBonus:"0"}];
describe("versioned commission policy",()=>{
 it("selects an editable tier with decimal math",()=>expect(commissionAmount("10000","86",tiers)).toBe("175.00"));
 it("rejects overlapping tiers",()=>expect(()=>assertNonOverlappingTiers([{minPercentage:"0",maxPercentage:"90",ratePercentage:"1",fixedBonus:"0"},{minPercentage:"80",ratePercentage:"2",fixedBonus:"0"}])).toThrow("OVERLAPPING_TIERS"));
 it("keeps a month-end sale pending until both configured conditions",()=>{const result=evaluateMaturity({rule:"BOTH_CONDITIONS_REQUIRED",fixedDays:15,minimumFulfilledPercentage:"50",minimumHoldDays:0,monthEndMinimumHoldDays:6,requireNoOpenRefund:true,requireNoOpenCancellation:true,requirePaymentReconciled:true},{daysSincePayment:16,fulfilledPercentage:"40",deliveryCompleted:false,manualApproval:false,openRefund:false,openCancellation:false,paymentReconciled:true,isMonthEndSale:true});expect(result.eligible).toBe(false);expect(result.reasons).toContain("FULFILLMENT_THRESHOLD_NOT_REACHED")});
});

