import { describe,expect,it } from "vitest";
import fs from "node:fs";
import path from "node:path";
const root=path.resolve(__dirname,"../.."); const sql=fs.readFileSync(path.join(root,"supabase/eco_healthy_schema_final.sql"),"utf8");
describe("security architecture",()=>{
 it("contains no giant bootstrap or blanket grants",()=>{expect(sql).not.toMatch(/erp_bootstrap/i);expect(sql).not.toMatch(/grant execute on all functions/i);expect(sql).not.toMatch(/grant select on all tables/i)});
 it("contains scoped RLS and investor PII isolation",()=>{expect(sql).toContain("eco_customers_scoped");expect(sql).toContain("eco_stops_rider");expect(sql).toContain("eco_investor_certified_metrics_v")});
 it("has idempotent finance and delivery transactions",()=>{expect(sql).toContain("eco_begin_idempotent('CONFIRM_PAYMENT'");expect(sql).toContain("client_event_id uuid not null unique");expect(sql).toContain("on conflict(order_id)")});
});
