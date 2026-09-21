export type Entity = { id: string; branchId: string; isDemo?: boolean };
export type Task = Entity & { title: string; status: string; dueAt?: number; openUntilResponse: boolean; response?: string; evidence?: string; reviewApproved: boolean };
export type Payment = Entity & { amount: number; submittedBy: string; status: "pending" | "confirmed"; confirmedBy?: string };
export type Session = Entity & { doctorId?: string; customerId: string; startsAt: number; endsAt: number; status: string; paymentConfirmed: boolean; notes?: string; recommendation?: string };

export class ErpWorkflowEngine {
  private sequence = 0;
  leads: Array<Entity & { name: string; status: string }> = [];
  customers: Array<Entity & { name: string; leadId?: string }> = [];
  quotations: Array<Entity & { customerId: string; amount: number; status: string }> = [];
  invoices: Array<Entity & { customerId: string; quotationId: string; amount: number; confirmedPaid: number }> = [];
  payments: Payment[] = [];
  subscriptions: Array<Entity & { customerId: string; invoiceId: string; value: number; deferred: number; recognized: number; status: string }> = [];
  commissions: Array<Entity & { beneficiaryId: string; amount: number; type: "sales" | "doctor" | "clawback"; status: string; sourceId: string }> = [];
  tasks: Task[] = [];
  notifications: Array<Entity & { event: string; recipientId: string; key: string }> = [];
  complaints: Array<Entity & { customerId: string; category: string; status: string }> = [];
  doctors: Array<Entity & { name: string; specialty: string; load: number }> = [];
  sessions: Session[] = [];
  calendarEvents: Array<Entity & { sessionId: string; externalId: string; meetUrl: string; key: string }> = [];

  private id(prefix: string) { this.sequence += 1; return `${prefix}-${this.sequence}`; }

  createLead(name: string, branchId: string, isDemo = false) {
    const lead = { id: this.id("lead"), name, branchId, status: "qualified", isDemo };
    this.leads.push(lead); return lead;
  }

  convertLead(leadId: string) {
    const lead = this.leads.find((item) => item.id === leadId);
    if (!lead || lead.status === "converted") throw new Error("lead is not convertible");
    const customer = { id: this.id("customer"), name: lead.name, branchId: lead.branchId, leadId: lead.id, isDemo: lead.isDemo };
    this.customers.push(customer); lead.status = "converted"; return customer;
  }

  createQuotation(customerId: string, amount: number) {
    const customer = this.customers.find((item) => item.id === customerId);
    if (!customer || amount <= 0) throw new Error("invalid quotation");
    const quotation = { id: this.id("quote"), customerId, branchId: customer.branchId, amount, status: "accepted", isDemo: customer.isDemo };
    this.quotations.push(quotation); return quotation;
  }

  invoiceQuotation(quotationId: string) {
    const quotation = this.quotations.find((item) => item.id === quotationId && item.status === "accepted");
    if (!quotation) throw new Error("accepted quotation required");
    const invoice = { id: this.id("invoice"), quotationId, customerId: quotation.customerId, branchId: quotation.branchId, amount: quotation.amount, confirmedPaid: 0, isDemo: quotation.isDemo };
    this.invoices.push(invoice); quotation.status = "converted"; return invoice;
  }

  submitPayment(invoiceId: string, amount: number, submittedBy: string) {
    const invoice = this.invoices.find((item) => item.id === invoiceId);
    if (!invoice || amount <= 0) throw new Error("invalid payment submission");
    const payment: Payment = { id: this.id("payment"), branchId: invoice.branchId, amount, submittedBy, status: "pending", isDemo: invoice.isDemo };
    this.payments.push(payment); return payment;
  }

  confirmedCash() { return this.payments.filter((payment) => payment.status === "confirmed").reduce((sum, payment) => sum + payment.amount, 0); }

  confirmPayment(paymentId: string, actorId: string) {
    const payment = this.payments.find((item) => item.id === paymentId);
    if (!payment || payment.status !== "pending") throw new Error("pending payment required");
    if (payment.submittedBy === actorId) throw new Error("maker cannot confirm own payment");
    payment.status = "confirmed"; payment.confirmedBy = actorId;
    const invoice = this.invoices.find((item) => item.branchId === payment.branchId && item.confirmedPaid < item.amount);
    if (invoice) invoice.confirmedPaid = Math.min(invoice.amount, invoice.confirmedPaid + payment.amount);
    this.commissions.push({ id: this.id("commission"), branchId: payment.branchId, beneficiaryId: payment.submittedBy, amount: payment.amount * 0.03, type: "sales", status: "eligible", sourceId: payment.id, isDemo: payment.isDemo });
    return payment;
  }

  activateSubscription(invoiceId: string) {
    const invoice = this.invoices.find((item) => item.id === invoiceId);
    if (!invoice || invoice.confirmedPaid <= 0) throw new Error("confirmed payment required");
    const subscription = { id: this.id("subscription"), customerId: invoice.customerId, invoiceId, branchId: invoice.branchId, value: invoice.confirmedPaid, deferred: invoice.confirmedPaid, recognized: 0, status: "active", isDemo: invoice.isDemo };
    this.subscriptions.push(subscription); return subscription;
  }

  confirmDelivery(subscriptionId: string, deliveryStatus: string) {
    const subscription = this.subscriptions.find((item) => item.id === subscriptionId);
    if (!subscription) throw new Error("subscription required");
    if (deliveryStatus !== "confirmed_delivered") return 0;
    const amount = Math.round((subscription.value / 30) * 100) / 100;
    subscription.recognized += amount; subscription.deferred -= amount; return amount;
  }

  deferredReconciliation(subscriptionId: string) {
    const subscription = this.subscriptions.find((item) => item.id === subscriptionId);
    if (!subscription) throw new Error("subscription required");
    return Math.round((subscription.value - subscription.recognized - subscription.deferred) * 100) / 100;
  }

  refund(customerId: string, amount: number) {
    const invoice = this.invoices.find((item) => item.customerId === customerId);
    if (!invoice || amount <= 0 || amount > invoice.confirmedPaid) throw new Error("refund exceeds confirmed balance");
    const commission = this.commissions.find((item) => item.type === "sales" && item.branchId === invoice.branchId);
    if (commission) this.commissions.push({ id: this.id("clawback"), branchId: invoice.branchId, beneficiaryId: commission.beneficiaryId, amount: -Math.min(commission.amount, commission.amount * amount / invoice.confirmedPaid), type: "clawback", status: "clawback_required", sourceId: invoice.id, isDemo: invoice.isDemo });
  }

  assignTask(title: string, branchId: string, assigneeId: string, options: { dueAt?: number; openUntilResponse?: boolean; isDemo?: boolean } = {}) {
    const task: Task = { id: this.id("task"), branchId, title, status: "assigned", dueAt: options.dueAt, openUntilResponse: options.openUntilResponse ?? false, reviewApproved: false, isDemo: options.isDemo };
    this.tasks.push(task);
    this.notifications.push({ id: this.id("notification"), branchId, event: "task.assigned", recipientId: assigneeId, key: `task.assigned:${task.id}`, isDemo: options.isDemo });
    return task;
  }

  respondTask(taskId: string, response: string, evidence?: string) {
    const task = this.tasks.find((item) => item.id === taskId); if (!task) throw new Error("task not found");
    task.response = response; task.evidence = evidence; task.status = "response_submitted"; return task;
  }

  approveTask(taskId: string) { const task = this.tasks.find((item) => item.id === taskId); if (!task) throw new Error("task not found"); task.reviewApproved = true; task.status = "completed"; return task; }

  completeTask(taskId: string) {
    const task = this.tasks.find((item) => item.id === taskId); if (!task) throw new Error("task not found");
    if (task.openUntilResponse && !task.response) throw new Error("official response required");
    if (!task.evidence) throw new Error("completion evidence required");
    if (!task.reviewApproved) { task.status = "in_review"; return task; }
    task.status = "completed"; return task;
  }

  escalateOverdue(now: number) {
    const overdue = this.tasks.filter((task) => task.dueAt && task.dueAt < now && !["completed", "cancelled"].includes(task.status));
    overdue.forEach((task) => this.notifications.push({ id: this.id("notification"), branchId: task.branchId, event: "task.overdue.manager", recipientId: "manager", key: `overdue:${task.id}`, isDemo: task.isDemo }));
    return overdue.length;
  }

  recordComplaint(customerId: string, category: string) {
    const customer = this.customers.find((item) => item.id === customerId); if (!customer) throw new Error("customer required");
    const complaint = { id: this.id("complaint"), branchId: customer.branchId, customerId, category, status: "open", isDemo: customer.isDemo };
    this.complaints.push(complaint); return complaint;
  }

  addDoctor(name: string, specialty: string, branchId: string, isDemo = false) {
    const doctor = { id: this.id("doctor"), name, specialty, branchId, load: 0, isDemo }; this.doctors.push(doctor); return doctor;
  }

  assignDoctorRoundRobin(specialty: string, branchId: string) {
    const eligible = this.doctors.filter((doctor) => doctor.specialty === specialty && doctor.branchId === branchId).sort((a, b) => a.load - b.load || a.id.localeCompare(b.id));
    if (!eligible.length) throw new Error("no eligible doctor"); eligible[0].load += 1; return eligible[0];
  }

  bookSession(customerId: string, doctorId: string, branchId: string, startsAt: number, endsAt: number, paymentConfirmed = false, isDemo = false) {
    if (this.sessions.some((session) => session.doctorId === doctorId && !["cancelled", "no_show"].includes(session.status) && startsAt < session.endsAt && endsAt > session.startsAt)) throw new Error("double booking");
    const session: Session = { id: this.id("session"), customerId, doctorId, branchId, startsAt, endsAt, status: paymentConfirmed ? "confirmed" : "awaiting_payment", paymentConfirmed, isDemo };
    this.sessions.push(session); return session;
  }

  syncMockCalendar(sessionId: string) {
    const existing = this.calendarEvents.find((event) => event.sessionId === sessionId); if (existing) return existing;
    const session = this.sessions.find((item) => item.id === sessionId); if (!session || !session.paymentConfirmed) throw new Error("confirmed session required");
    const event = { id: this.id("calendar"), branchId: session.branchId, sessionId, externalId: `mock-${sessionId}`, meetUrl: `https://meet.google.com/mock-${sessionId}`, key: `calendar:${sessionId}`, isDemo: session.isDemo };
    this.calendarEvents.push(event); session.status = "scheduled"; return event;
  }

  completeSession(sessionId: string, notes: string) {
    const session = this.sessions.find((item) => item.id === sessionId); if (!session || !session.paymentConfirmed) throw new Error("confirmed payment required");
    if (!notes.trim()) throw new Error("notes required"); session.notes = notes; session.status = "completed"; return session;
  }

  recommendPackage(sessionId: string, packageName: string) {
    const session = this.sessions.find((item) => item.id === sessionId && item.status === "completed"); if (!session) throw new Error("completed session required");
    session.recommendation = packageName; return session;
  }

  earnDoctorCommission(sessionId: string, amount: number) {
    const session = this.sessions.find((item) => item.id === sessionId); if (!session || session.status !== "completed" || !session.paymentConfirmed || !session.notes) throw new Error("commission is not eligible");
    const entry = { id: this.id("doctor-commission"), branchId: session.branchId, beneficiaryId: session.doctorId || "", amount, type: "doctor" as const, status: "eligible", sourceId: session.id, isDemo: session.isDemo };
    this.commissions.push(entry); return entry;
  }

  visibleByBranches<T extends Entity>(rows: T[], allowed: string[]) { return rows.filter((row) => allowed.includes(row.branchId)); }
  doctorFinancials(doctorId: string) { return this.commissions.filter((entry) => entry.type === "doctor" && entry.beneficiaryId === doctorId); }

  removeDemoData() {
    const collections: Array<Array<{ isDemo?: boolean }>> = [this.leads, this.customers, this.quotations, this.invoices, this.payments, this.subscriptions, this.commissions, this.tasks, this.notifications, this.complaints, this.doctors, this.sessions, this.calendarEvents];
    let removed = 0; collections.forEach((collection) => { for (let index = collection.length - 1; index >= 0; index -= 1) if (collection[index].isDemo) { collection.splice(index, 1); removed += 1; } });
    return removed;
  }
}
