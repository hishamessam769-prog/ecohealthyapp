import { defineConfig, devices } from "@playwright/test";

const baseURL = process.env.HOSTED_E2E_BASE_URL;
if (!baseURL) throw new Error("HOSTED_E2E_BASE_URL is required for the hosted staging test.");

export default defineConfig({
  testDir: "./tests/e2e",
  testMatch: "hosted-commercial.spec.ts",
  timeout: 180_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [["list"], ["json", { outputFile: "outputs/hosted-e2e/results.json" }]],
  outputDir: "outputs/hosted-e2e/artifacts",
  use: {
    baseURL,
    locale: "ar-EG",
    timezoneId: "Africa/Cairo",
    trace: "on",
    video: "on",
    screenshot: "only-on-failure",
    ...devices["Desktop Chrome"],
  },
});
