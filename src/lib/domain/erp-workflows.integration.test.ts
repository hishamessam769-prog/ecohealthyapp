import { describe, expect, it } from "vitest";
import { ErpWorkflowEngine } from "@/lib/domain/erp-workflows";

function salesFlow() {
  const engine = new ErpWorkflowEngine();
  const lead = engine.createLead("Customer One", "branch-a");
  const customer = engine.convertLead(lead.id);
  const quotation = engine.createQuotation(customer.id, 6000);
  const invoice = engine.invoiceQuotation(quotation.id);
  return { engine, lead, customer, quotation, invoice };
}

describe("commercial end-to-end workflow", () => {
  it("converts a lead to customer and quotation to invoice", () => {
    const { lead, customer, quotation, invoice } = salesFlow();
    expect(lead.status).toBe("converted"); expect(customer.leadId).toBe(lead.id); expect(invoice.quotationId).toBe(quotation.id);
  });
  it("does not treat payment proof as confirmed cash", () => {
    const { engine, invoice } = salesFlow(); engine.submitPayment(invoice.id, 6000, "sales"); expect(engine.confirmedCash()).toBe(0);
  });
  it("requires finance maker-checker and then confirms cash", () => {
    const { engine, invoice } = salesFlow(); const payment = engine.submitPayment(invoice.id, 6000, "sales");
    expect(() => engine.confirmPayment(payment.id, "sales")).toThrow("maker"); engine.confirmPayment(payment.id, "finance"); expect(engine.confirmedCash()).toBe(6000);
  });
  it("activates only after confirmed payment and updates target/commission", () => {
    const { engine, invoice } = salesFlow(); expect(() => engine.activateSubscription(invoice.id)).toThrow("confirmed");
    const payment = engine.submitPayment(invoice.id, 6000, "sales"); engine.confirmPayment(payment.id, "finance");
    expect(engine.activateSubscription(invoice.id).status).toBe("active"); expect(engine.commissions[0].amount).toBe(180);
  });
  it("recognizes only confirmed delivery and reconciles deferred revenue", () => {
    const { engine, invoice } = salesFlow(); const payment = engine.submitPayment(invoice.id, 6000, "sales"); engine.confirmPayment(payment.id, "finance"); const subscription = engine.activateSubscription(invoice.id);
    expect(engine.confirmDelivery(subscription.id, "planned")).toBe(0); expect(engine.confirmDelivery(subscription.id, "confirmed_delivered")).toBe(200); expect(engine.deferredReconciliation(subscription.id)).toBe(0);
  });
  it("creates a commission clawback after refund", () => {
    const { engine, customer, invoice } = salesFlow(); const payment = engine.submitPayment(invoice.id, 6000, "sales"); engine.confirmPayment(payment.id, "finance"); engine.refund(customer.id, 1000);
    expect(engine.commissions.some((entry) => entry.type === "clawback" && entry.amount < 0)).toBe(true);
  });
});

describe("tasks, complaints and notifications", () => {
  it("assigns a task and creates one notification", () => {
    const engine = new ErpWorkflowEngine(); const task = engine.assignTask("Follow up", "a", "employee"); expect(task.status).toBe("assigned"); expect(engine.notifications[0].event).toBe("task.assigned");
  });
  it("keeps open task waiting until response, evidence and review", () => {
    const engine = new ErpWorkflowEngine(); const task = engine.assignTask("Open response", "a", "employee", { openUntilResponse: true });
    expect(() => engine.completeTask(task.id)).toThrow("response"); engine.respondTask(task.id, "Official response", "proof.pdf"); expect(engine.completeTask(task.id).status).toBe("in_review"); expect(engine.approveTask(task.id).status).toBe("completed");
  });
  it("escalates overdue tasks to manager", () => {
    const engine = new ErpWorkflowEngine(); engine.assignTask("Overdue", "a", "employee", { dueAt: Date.now() - 1000 }); expect(engine.escalateOverdue(Date.now())).toBe(1); expect(engine.notifications.at(-1)?.event).toBe("task.overdue.manager");
  });
  it("records complaint linked to customer", () => {
    const { engine, customer } = salesFlow(); const complaint = engine.recordComplaint(customer.id, "service"); expect(complaint.status).toBe("open"); expect(complaint.customerId).toBe(customer.id);
  });
});

describe("doctor booking and accounting", () => {
  it("round-robins to the least loaded eligible doctor", () => {
    const engine = new ErpWorkflowEngine(); const first = engine.addDoctor("D1", "nutrition", "a"); const second = engine.addDoctor("D2", "nutrition", "a");
    expect(engine.assignDoctorRoundRobin("nutrition", "a").id).toBe(first.id); expect(engine.assignDoctorRoundRobin("nutrition", "a").id).toBe(second.id);
  });
  it("prevents double booking", () => {
    const engine = new ErpWorkflowEngine(); const doctor = engine.addDoctor("D1", "nutrition", "a"); engine.bookSession("c1", doctor.id, "a", 100, 200, true);
    expect(() => engine.bookSession("c2", doctor.id, "a", 150, 250, true)).toThrow("double booking");
  });
  it("does not confirm unpaid booking", () => {
    const engine = new ErpWorkflowEngine(); const doctor = engine.addDoctor("D1", "nutrition", "a"); const session = engine.bookSession("c1", doctor.id, "a", 100, 200, false); expect(session.status).toBe("awaiting_payment");
  });
  it("creates one mock Calendar/Meet event across retries", () => {
    const engine = new ErpWorkflowEngine(); const doctor = engine.addDoctor("D1", "nutrition", "a"); const session = engine.bookSession("c1", doctor.id, "a", 100, 200, true);
    expect(engine.syncMockCalendar(session.id).id).toBe(engine.syncMockCalendar(session.id).id); expect(engine.calendarEvents).toHaveLength(1); expect(engine.calendarEvents[0].meetUrl).toContain("meet.google.com/mock");
  });
  it("completes with notes, recommends a plan and earns eligible commission", () => {
    const engine = new ErpWorkflowEngine(); const doctor = engine.addDoctor("D1", "nutrition", "a"); const session = engine.bookSession("c1", doctor.id, "a", 100, 200, true);
    engine.completeSession(session.id, "Outcome and notes"); engine.recommendPackage(session.id, "Eco 30"); const commission = engine.earnDoctorCommission(session.id, 250);
    expect(session.recommendation).toBe("Eco 30"); expect(commission.status).toBe("eligible");
  });
  it("limits each doctor to their own financial data", () => {
    const engine = new ErpWorkflowEngine(); const d1 = engine.addDoctor("D1", "nutrition", "a"); const d2 = engine.addDoctor("D2", "nutrition", "a");
    const s1 = engine.bookSession("c1", d1.id, "a", 100, 200, true); const s2 = engine.bookSession("c2", d2.id, "a", 300, 400, true);
    engine.completeSession(s1.id, "done"); engine.completeSession(s2.id, "done"); engine.earnDoctorCommission(s1.id, 250); engine.earnDoctorCommission(s2.id, 300);
    expect(engine.doctorFinancials(d1.id)).toHaveLength(1); expect(engine.doctorFinancials(d1.id)[0].beneficiaryId).toBe(d1.id);
  });
});

describe("scope and demo safety", () => {
  it("prevents branch A from seeing branch B", () => {
    const engine = new ErpWorkflowEngine(); engine.createLead("A", "a"); engine.createLead("B", "b"); expect(engine.visibleByBranches(engine.leads, ["a"]).map((row) => row.name)).toEqual(["A"]);
  });
  it("removes demo records without touching real data", () => {
    const engine = new ErpWorkflowEngine(); engine.createLead("Real", "a", false); engine.createLead("Demo", "a", true); const removed = engine.removeDemoData(); expect(removed).toBe(1); expect(engine.leads.map((lead) => lead.name)).toEqual(["Real"]);
  });
});
