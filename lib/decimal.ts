import Decimal from "decimal.js";

Decimal.set({ precision: 28, rounding: Decimal.ROUND_HALF_UP });

export function money(value: Decimal.Value) {
  return new Decimal(value).toDecimalPlaces(2);
}

export function calculateInvoice(input: { lines: Array<{ quantity: string; unitPrice: string; discount: string; taxRate: string }>; deliveryFees: string }) {
  let subtotal = new Decimal(0);
  let discount = new Decimal(0);
  let tax = new Decimal(0);
  for (const line of input.lines) {
    const base = money(line.quantity).mul(money(line.unitPrice));
    const lineDiscount = money(line.discount);
    subtotal = subtotal.add(base);
    discount = discount.add(lineDiscount);
    tax = tax.add(base.sub(lineDiscount).mul(new Decimal(line.taxRate).div(100)));
  }
  const delivery = money(input.deliveryFees);
  return {
    subtotal: money(subtotal).toFixed(2),
    discount: money(discount).toFixed(2),
    tax: money(tax).toFixed(2),
    deliveryFees: delivery.toFixed(2),
    total: money(subtotal.sub(discount).add(tax).add(delivery)).toFixed(2),
  };
}
