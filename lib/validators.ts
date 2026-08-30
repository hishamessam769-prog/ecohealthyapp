import { z } from "zod";

export const uuid = z.string().uuid();
export const moneyString = z.union([z.string(), z.number()]).transform(String).pipe(z.string().regex(/^\d{1,12}(\.\d{1,2})?$/));
export const idempotencyKey = z.string().min(8).max(120);
const optionalCoordinate = (minimum: number, maximum: number) => z.preprocess((value) => value === "" || value == null ? undefined : value, z.coerce.number().min(minimum).max(maximum).optional());
const optionalMoney = z.preprocess((value) => value === "" || value == null ? undefined : value, moneyString.optional());

export const createLeadSchema = z.object({ full_name: z.string().min(2).max(160), phone: z.string().min(10).max(20), source_code: z.string().min(2).max(50), campaign_id: uuid.optional(), notes: z.string().max(2000).optional() });
export const createCustomerSchema = z.object({
  full_name: z.string().min(2).max(160),
  phone: z.string().min(10).max(20),
  email: z.string().email().optional().or(z.literal("")),
  zone_id: uuid,
  address_line: z.string().min(5).max(500),
  map_url: z.string().url().max(1000).optional().or(z.literal("")),
  latitude: optionalCoordinate(-90, 90),
  longitude: optionalCoordinate(-180, 180),
  delivery_window_id: uuid.optional().or(z.literal("")),
  sales_owner_id: uuid.optional().or(z.literal("")),
  dietary_notes: z.string().max(3000).optional(),
});
export const createInvoiceSchema = z.object({
  customer_id: uuid,
  order_type: z.enum(["SUBSCRIPTION", "A_LA_CARTE", "RENEWAL", "REACTIVATION", "CORPORATE"]),
  pricing_mode: z.enum(["CATALOG", "CUSTOM"]),
  package_version_id: uuid.optional().or(z.literal("")),
  custom_description: z.string().max(240).optional(),
  custom_price: optionalMoney,
  custom_service_days: z.preprocess((value) => value === "" ? undefined : value, z.coerce.number().int().positive().max(365).optional()),
  custom_package_type: z.enum(["LUNCH_ONLY", "AM", "BM", "FULL_DAY"]).optional().or(z.literal("")),
  discount_percentage: z.preprocess((value) => value === "" ? 0 : value, z.coerce.number().min(0).max(100).default(0)),
  start_date: z.string().date(),
  payment_date: z.string().date(),
  address_id: uuid,
  delivery_window_id: uuid,
  payment_method: z.enum(["CASH", "INSTAPAY", "BANK_TRANSFER", "WALLET", "VISA", "PAYMENT_LINK", "WEBSITE_APP"]),
  promotion_code: z.string().max(60).optional(),
  notes: z.string().max(2000).optional(),
  proof_path: z.string().max(500).optional(),
  payment_reference: z.string().max(160).optional(),
  idempotency_key: idempotencyKey,
}).superRefine((value, context) => {
  if (value.pricing_mode === "CATALOG" && !value.package_version_id) context.addIssue({ code: "custom", path: ["package_version_id"], message: "اختر باكدج من قائمة الأسعار" });
  if (value.pricing_mode === "CUSTOM" && (!value.custom_description || !value.custom_price)) context.addIssue({ code: "custom", path: ["custom_description"], message: "اكتب اسم وسعر الاشتراك الخاص" });
  if (value.pricing_mode === "CUSTOM" && value.order_type !== "A_LA_CARTE" && (!value.custom_service_days || !value.custom_package_type)) context.addIssue({ code: "custom", path: ["custom_service_days"], message: "حدد أيام ونوع الاشتراك الخاص" });
  if (value.payment_method !== "CASH" && !value.payment_reference) context.addIssue({ code: "custom", path: ["payment_reference"], message: "مرجع الدفع مطلوب" });
});
export const verifyPaymentSchema = z.object({ payment_id: uuid, amount_received: moneyString, currency: z.string().length(3).default("EGP"), account_id: uuid, reference: z.string().min(3).max(160), payer: z.string().min(2).max(160), receipt_date: z.string().date(), exception_note: z.string().max(2000).optional(), idempotency_key: idempotencyKey });
export const subscriptionChangeSchema = z.object({ subscription_id: uuid, change_type: z.enum(["PAUSE", "RESUME", "SKIP", "SWAP", "UPGRADE", "DOWNGRADE", "ADDRESS_CHANGE", "WINDOW_CHANGE", "CANCEL"]), effective_from: z.string().date(), effective_to: z.preprocess((value) => value === "" ? undefined : value, z.string().date().optional()), payload: z.record(z.string(), z.unknown()).default({}), reason: z.string().min(3).max(1000), idempotency_key: idempotencyKey });
export const deliveryEventSchema = z.object({ route_stop_id: uuid, event_type: z.enum(["ARRIVED", "DELIVERED", "FAILED"]), client_event_id: uuid, device_time: z.string().datetime(), failure_reason: z.string().max(500).optional(), otp: z.string().max(12).optional(), pod_path: z.string().max(500).optional(), latitude: z.number().optional(), longitude: z.number().optional(), cash_amount: moneyString.optional() });
