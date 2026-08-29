export type Role = "admin" | "sales" | "cs" | "kitchen" | "delivery" | "accounting";

export type Zone = 1 | 2 | 3 | 4;
export type OrderKind = "Subscription" | "AdHoc";
export type OrderStatus = "Pending Accounting" | "Approved" | "Rejected" | "Canceled";
export type PaymentMethod = "Cash" | "InstaPay" | "Website/App" | "Bank Transfer";
export type PaymentStatus = "Pending" | "Verified" | "Rejected" | "COD";
export type SubscriptionStatus = "Active" | "Paused" | "Finished" | "Canceled";
export type DeliveryFrequency = "Daily" | "Weekly";
export type KitchenStatus = "Planned" | "Sent" | "In Prep" | "Ready";
export type DeliveryStatus = "Pending" | "Out for delivery" | "Delivered" | "Failed";
export type MealSlot = "Breakfast" | "Lunch" | "Dinner" | "Snack";
export type PackageSize = "Regular" | "Hero" | "Custom";

export type Employee = { id: string; name: string; role: Role; active: boolean };

export type Client = {
  id: string; name: string; phone: string; email?: string; zone: Zone; address: string;
  locationUrl: string; dietaryNotes: string; strictExclusions: string[]; preferences: string[];
  totalPaid: number; createdAt: string; isDemo?: boolean;
};

export type Complaint = {
  id: string; clientId: string; category: string; details: string;
  status: "Open" | "Resolved"; createdAt: string;
};

export type Meal = {
  id: string; name: string; code: string; slot: MealSlot; regularCost: number;
  heroCost: number; active: boolean;
};

export type Package = {
  id: string; name: string; code: string; days: number; priceRegular: number;
  priceHero: number; mealSlots: MealSlot[]; active: boolean;
};

export type MenuEntry = { id: string; date: string; slot: MealSlot; mealId: string; notes?: string };

export type Order = {
  id: string; orderNumber: string; kind: OrderKind; clientId: string; packageId?: string;
  size: PackageSize; startDate: string; deliveryDate?: string; frequency: DeliveryFrequency;
  weeklyDay?: number; totalDays: number; amount: number; deliveryFees: number; discount: number;
  paymentMethod: PaymentMethod; paymentStatus: PaymentStatus; referenceId?: string; proofName?: string;
  status: OrderStatus; salesRepId: string; createdAt: string; adHocMealId?: string; notes?: string;
};

export type Subscription = {
  id: string; subscriptionNumber: string; orderId: string; clientId: string; packageId: string;
  size: PackageSize; startDate: string; frequency: DeliveryFrequency; weeklyDay?: number;
  totalDays: number; consumedDays: number; status: SubscriptionStatus; pauseFrom?: string;
  pauseUntil?: string; indefinitePause?: boolean; firstDeliveryCompleted: boolean; createdAt: string;
};

export type FulfillmentDay = {
  id: string; orderId: string; subscriptionId?: string; clientId: string; date: string;
  dayNumber: number; mealId: string; slot: MealSlot; size: PackageSize; zone: Zone;
  status: KitchenStatus; source: "Monthly Menu" | "Meal Swap" | "Ad Hoc";
  manualAfterCutoff?: boolean; skipped?: boolean;
};

export type Rider = { id: string; name: string; phone: string; active: boolean };

export type DeliveryStop = {
  id: string; fulfillmentId: string; clientId: string; orderId: string; date: string;
  zone: Zone; riderId?: string; sequence: number; status: DeliveryStatus;
  codExpected: number; cashCollected: number; collectionMethod?: PaymentMethod; deliveredAt?: string;
};

export type Payment = {
  id: string; orderId: string; clientId: string; method: PaymentMethod; amount: number;
  status: PaymentStatus; referenceId?: string; proofName?: string; verifiedAt?: string;
  verifiedBy?: string; createdAt: string;
};

export type Cancellation = {
  id: string; subscriptionId: string; clientId: string; orderId: string; remainingValue: number;
  consumedValue: number; consumedPenalty: number; deliveryPenalty: number; refundAmount: number;
  reason: string; status: "Requested" | "Reviewed" | "Transferred" | "Rejected";
  receiptName?: string; createdAt: string;
};

export type Notification = { id: string; role: Role; title: string; body: string; read: boolean; createdAt: string };
export type SalesTarget = { id: string; employeeId: string; month: string; target: number };
export type Reconciliation = {
  id: string; date: string; expectedCash: number; actualCash: number;
  instapayVerified: number; status: "Open" | "Closed";
};

export type ERPState = {
  employees: Employee[]; clients: Client[]; complaints: Complaint[]; meals: Meal[];
  packages: Package[]; menu: MenuEntry[]; orders: Order[]; subscriptions: Subscription[];
  fulfillment: FulfillmentDay[]; riders: Rider[]; deliveries: DeliveryStop[]; payments: Payment[];
  cancellations: Cancellation[]; notifications: Notification[]; salesTargets: SalesTarget[];
  reconciliations: Reconciliation[];
};

export type NewClientInput = Omit<Client, "id" | "totalPaid" | "createdAt">;
export type NewOrderInput = Omit<Order, "id" | "orderNumber" | "status" | "paymentStatus" | "createdAt">;
