import { expect,test } from "@playwright/test";
test("unauthenticated users are redirected to Arabic login",async({page})=>{await page.goto("/");await expect(page).toHaveURL(/login/);await expect(page.getByRole("heading",{name:/تسجيل الدخول/})).toBeVisible()});

