import { mkdir } from "node:fs/promises";
import { join } from "node:path";
import { expect, test } from "@playwright/test";

const outputDir = join(process.cwd(), "outputs", "screenshots");
const screens = [
  ["dashboard", "/dashboard"],
  ["users", "/admin/users"],
  ["roles", "/admin/roles"],
  ["projects", "/projects"],
  ["tasks", "/tasks"],
  ["leads", "/crm/leads"],
  ["customers", "/crm/customers"],
  ["sales", "/sales"],
  ["invoices", "/sales/invoices"],
  ["finance", "/finance/payments"],
  ["subscriptions", "/subscriptions"],
  ["subscriber-operations", "/operations/subscribers"],
  ["complaints", "/complaints"],
  ["doctors", "/doctors"],
  ["doctor-calendar", "/doctors/calendar"],
  ["doctor-sessions", "/doctors/sessions"],
  ["doctor-accounting", "/doctors/accounting"],
  ["notifications", "/notifications"],
  ["settings", "/settings"],
] as const;

test.beforeAll(async () => {
  await mkdir(outputDir, { recursive: true });
});

test("all final routes render, protect navigation, and capture responsive evidence", async ({ page }, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  const formFactor = testInfo.project.name.startsWith("mobile") ? "mobile" : "desktop";

  for (const [slug, path] of screens) {
    errors.length = 0;
    await page.goto(path, { waitUntil: "networkidle" });
    await expect(page.locator("main h1")).toBeVisible();
    await expect(page.getByText("وضع المعاينة المحلية — لا توجد بيانات إنتاجية", { exact: true })).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
    expect(overflow).toBe(false);
    expect(errors).toEqual([]);
    await page.screenshot({ path: join(outputDir, `${slug}-${formFactor}.png`), fullPage: true });
  }

  await page.goto("/admin/permissions", { waitUntil: "networkidle" });
  await expect(page.locator("main h1")).toBeVisible();
  await expect(page.locator('nav[aria-label="Main navigation"]:visible, nav[aria-label="Mobile navigation"]:visible')).toBeVisible();
});
