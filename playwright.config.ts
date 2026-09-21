import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  testIgnore: "hosted-commercial.spec.ts",
  timeout: 45_000,
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [["list"], ["json", { outputFile: "outputs/e2e-results.json" }]],
  use: {
    baseURL: "http://127.0.0.1:3100",
    locale: "ar-EG",
    timezoneId: "Africa/Cairo",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    launchOptions: {
      args: ["--single-process", "--no-zygote", "--disable-gpu-process"],
    },
  },
  webServer: {
    command: "NEXT_PUBLIC_APP_PREVIEW_MODE=true ./node_modules/.bin/next start -p 3100",
    url: "http://127.0.0.1:3100/dashboard",
    timeout: 120_000,
    reuseExistingServer: true,
  },
  projects: [
    { name: "desktop-chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "mobile-chromium", use: { ...devices["Pixel 7"] } },
  ],
});
