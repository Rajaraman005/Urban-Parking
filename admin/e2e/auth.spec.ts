import { expect, test } from "@playwright/test";

test("protected admin routes redirect to login without a session cookie", async ({ page }) => {
  await page.goto("/reviews");
  await expect(page).toHaveURL(/\/login/);
  await expect(page.getByRole("heading", { name: "Admin sign in" })).toBeVisible();
});
