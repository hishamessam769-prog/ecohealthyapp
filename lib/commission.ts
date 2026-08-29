import Decimal from "decimal.js";

export type CommissionTier = { minPercentage: string; maxPercentage?: string; ratePercentage: string; fixedBonus: string };
export type MaturityPolicy = {
  rule: "FIXED_DAYS_AFTER_PAYMENT" | "PERCENTAGE_OF_SUBSCRIPTION_FULFILLED" | "BOTH_CONDITIONS_REQUIRED" | "EITHER_CONDITION_REQUIRED" | "DELIVERY_COMPLETED" | "MANUAL_FINANCE_APPROVAL";
  fixedDays: number; minimumFulfilledPercentage: string; minimumHoldDays: number; monthEndMinimumHoldDays: number;
  requireNoOpenRefund: boolean; requireNoOpenCancellation: boolean; requirePaymentReconciled: boolean;
};

export function assertNonOverlappingTiers(tiers: CommissionTier[]) {
  const sorted = [...tiers].sort((a,b)=>new Decimal(a.minPercentage).cmp(b.minPercentage));
  for (let index=0; index<sorted.length; index+=1) {
    const current=sorted[index]; const next=sorted[index+1];
    if (!current) continue;
    if (new Decimal(current.ratePercentage).isNegative()) throw new Error("NEGATIVE_COMMISSION_RATE");
    if (current.maxPercentage && new Decimal(current.maxPercentage).lte(current.minPercentage)) throw new Error("INVALID_TIER_RANGE");
    if (next && (!current.maxPercentage || new Decimal(current.maxPercentage).gt(next.minPercentage))) throw new Error("OVERLAPPING_TIERS");
  }
  return sorted;
}

export function commissionAmount(value: string, achievement: string, tiers: CommissionTier[]) {
  const tier=assertNonOverlappingTiers(tiers).filter((item)=>new Decimal(achievement).gte(item.minPercentage) && (!item.maxPercentage || new Decimal(achievement).lt(item.maxPercentage))).at(-1);
  if (!tier) return "0.00";
  return new Decimal(value).mul(tier.ratePercentage).div(100).add(tier.fixedBonus).toDecimalPlaces(2).toFixed(2);
}

export function evaluateMaturity(policy: MaturityPolicy, facts: { daysSincePayment:number; fulfilledPercentage:string; deliveryCompleted:boolean; manualApproval:boolean; openRefund:boolean; openCancellation:boolean; paymentReconciled:boolean; isMonthEndSale:boolean }) {
  const hold=Math.max(policy.minimumHoldDays, facts.isMonthEndSale ? policy.monthEndMinimumHoldDays : 0);
  const days=facts.daysSincePayment>=Math.max(policy.fixedDays,hold);
  const fulfilled=new Decimal(facts.fulfilledPercentage).gte(policy.minimumFulfilledPercentage);
  const prerequisites=(!policy.requireNoOpenRefund||!facts.openRefund)&&(!policy.requireNoOpenCancellation||!facts.openCancellation)&&(!policy.requirePaymentReconciled||facts.paymentReconciled);
  const core=policy.rule==="FIXED_DAYS_AFTER_PAYMENT"?days:policy.rule==="PERCENTAGE_OF_SUBSCRIPTION_FULFILLED"?fulfilled:policy.rule==="BOTH_CONDITIONS_REQUIRED"?days&&fulfilled:policy.rule==="EITHER_CONDITION_REQUIRED"?days||fulfilled:policy.rule==="DELIVERY_COMPLETED"?facts.deliveryCompleted:facts.manualApproval;
  const eligible=core&&prerequisites; const reasons:string[]=[];
  if(!days)reasons.push("MINIMUM_HOLD_NOT_REACHED");if(!fulfilled)reasons.push("FULFILLMENT_THRESHOLD_NOT_REACHED");if(facts.openRefund)reasons.push("OPEN_REFUND");if(facts.openCancellation)reasons.push("OPEN_CANCELLATION");if(policy.requirePaymentReconciled&&!facts.paymentReconciled)reasons.push("PAYMENT_NOT_RECONCILED");
  return {eligible,reasons};
}

