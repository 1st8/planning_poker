import { test, expect } from "@playwright/test";
import { loginAsMockUser, syncLV } from "../utils.js";

test.describe("Personal Issue Notes", () => {
  test("notes are displayed for multiple issues in magic estimation", async ({
    page,
  }) => {
    const note1 = "Check authentication requirements";
    const note2 = "Consider mobile-first approach";
    const note3 = "WebSocket implementation needed";
    const sessionId = "test-session-multiple";

    // Step 1: Login as Alice
    await page.goto(`/auth/mock/alice`);

    // Verify login succeeded
    await expect(page.locator("text=Alice")).toBeVisible();

    // Verify we're in magic estimation mode by default
    await expect(
      page.locator("button", { hasText: "Change mode to PlanningPoker" })
    ).toBeVisible();

    // Step 2: Write notes for multiple issues
    // Note for issue 1
    await page
      .locator("li")
      .filter({ hasText: "Add user profile page" })
      .locator("button", { hasText: "View" })
      .click();
    await syncLV(page);
    await page.locator('textarea[placeholder*="personal notes"]').fill(note1);
    await page.waitForTimeout(600);
    await page.locator("button", { hasText: "Back" }).click();
    await syncLV(page);

    // Note for issue 2
    await page
      .locator("li")
      .filter({ hasText: "Fix login page styling on mobile" })
      .locator("button", { hasText: "View" })
      .click();
    await syncLV(page);
    await page.locator('textarea[placeholder*="personal notes"]').fill(note2);
    await page.waitForTimeout(600);
    await page.locator("button", { hasText: "Back" }).click();
    await syncLV(page);

    // Note for issue 3
    await page
      .locator("li")
      .filter({ hasText: "Implement real-time notifications" })
      .locator("button", { hasText: "View" })
      .click();
    await syncLV(page);
    await page.locator('textarea[placeholder*="personal notes"]').fill(note3);
    await page.waitForTimeout(600);
    await page.locator("button", { hasText: "Back" }).click();
    await syncLV(page);

    // Step 3: Start Magic Estimation
    await page.locator("button", { hasText: "Start Magic Estimation" }).click();
    await syncLV(page);

    // Step 4: Verify all three notes are displayed next to their respective issues
    const issue1Card = page
      .locator(".issue-card")
      .filter({ hasText: "Add user profile page" });
    await expect(issue1Card.locator("text=" + note1)).toBeVisible();

    const issue2Card = page
      .locator(".issue-card")
      .filter({ hasText: "Fix login page styling on mobile" });
    await expect(issue2Card.locator("text=" + note2)).toBeVisible();

    const issue3Card = page
      .locator(".issue-card")
      .filter({ hasText: "Implement real-time notifications" });
    await expect(issue3Card.locator("text=" + note3)).toBeVisible();
  });
});
