export type Role = "admin" | "sales" | "cs" | "kitchen" | "delivery" | "accounting";

export type Issue = {
  id: string;
  text: string;
  imageUrl?: string;
  createdAt: string;
};

export type Client = {
  id: string;
  name: string;
  phone: string;
  zone: 1 | 2 | 3 | 4;
  locationUrl: string;
  dietaryNotes: string;
  issues: Issue[];
};

export type SubscriptionStatus = "Active" | "Paused" | "Finished" | "Canceled";
export type DeliveryType = "Daily" | "Weekly";
export type PaymentType = "PrePaid" | "PayOnFirstDelivery";
export type KitchenStatus = "Pending" | "In Prep" | "Approved/Done";
export type MealType = "Standard" | "LC" | "High Protein";

export type FulfillmentDay = {
  id: string;
  subscriptionId: string;
  dayNumber: number;
  date: string;
  meal: string;
  mealType: MealType;
  zone: 1 | 2 | 3 | 4;
  kitchenStatus: KitchenStatus;
  manualOverride?: boolean;
};

export type Subscription = {
  id: string;
  clientId: string;
  salesRepId: string;
  program: string;
  totalDays: number;
  consumedDays: number;
  totalPrice: number;
  status: SubscriptionStatus;
  deliveryType: DeliveryType;
  weeklyDay?: string;
  paymentType: PaymentType;
  amountPaid: number;
  paymentVerified: boolean;
  firstDeliveryCompleted: boolean;
  deliveryDaysLogged: number;
};

export type DeliveryStop = {
  id: string;
  fulfillmentDayId: string;
  subscriptionId: string;
  clientId: string;
  zone: 1 | 2 | 3 | 4;
  rider: string;
  status: "Pending" | "Delivered" | "Failed";
  cashExpected: number;
  collectionLogged: boolean;
};

export type CancellationRequest = {
  id: string;
  subscriptionId: string;
  clientId: string;
  remainingValue: number;
  consumedValue: number;
  consumedPenalty: number;
  deliveryPenalty: number;
  refundAmount: number;
  status: "Requested" | "Reviewed" | "Transferred";
  receiptUrl?: string;
  createdAt: string;
};

export type AppNotification = {
  id: string;
  role: Role;
  title: string;
  body: string;
  type: "kitchen" | "accounting" | "sales" | "system";
  read: boolean;
  createdAt: string;
};

export type SalesRep = {
  id: string;
  name: string;
  target: number;
};

