import { expect, test } from "@playwright/test";

test("harness_reports_intentional_mismatch", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle("Questify");
  await expect(page.getByRole("main")).toBeVisible();
  expect(1).toBe(1);
});
