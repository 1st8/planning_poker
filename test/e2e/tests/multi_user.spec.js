import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV, resetSession } from '../utils.js';

test.describe('Multi-user Planning Session', () => {

  test.beforeEach(async ({ request }) => {
    // Reset session before each test
    await resetSession(request);
  });

  test('readiness flow: mark ready, sync, withdraw, and clear on end', async ({ browser }) => {
    // Create two separate browser contexts (isolated sessions)
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();
    const page1 = await context1.newPage();
    const page2 = await context2.newPage();

    try {
      // Both users login and navigate
      await loginAsMockUser(page1, 'alice');
      await loginAsMockUser(page2, 'bob');

      // Default mode is magic_estimation, so View buttons should already be visible
      // Wait for both pages to show View buttons
      await expect(page1.locator('button', { hasText: 'View' }).first()).toBeVisible({ timeout: 10000 });
      await expect(page2.locator('button', { hasText: 'View' }).first()).toBeVisible({ timeout: 10000 });

      // User 1 clicks "View" on an issue to start issue planning
      // This enters voting state with magic_estimation mode where readiness controls appear
      await page1.locator('button', { hasText: 'View' }).first().click();
      await syncLV(page1);

      // Verify page1 transitioned to voting
      await expect(page1.getByRole('heading', { name: 'Voting' })).toBeVisible({ timeout: 10000 });

      // User 2 should see the voting view (issue planning) via PubSub
      await expect(page2.getByRole('heading', { name: 'Voting' })).toBeVisible({ timeout: 10000 });

      // The readiness button lives below the personal notes and starts unpressed
      const readyButton = page1.getByRole('button', { name: "I'm ready" });
      await expect(readyButton).toHaveAttribute('aria-pressed', 'false');

      const participantsPage2 = page2.locator('aside').filter({
        has: page2.getByRole('heading', { name: 'Participants' })
      });
      const aliceReady = participantsPage2.locator('li', { hasText: 'Alice' }).getByText('ready');
      await expect(participantsPage2.locator('text=Alice')).toBeVisible();
      await expect(aliceReady).toHaveCount(0);

      // User 1 marks themselves ready
      await readyButton.click();
      await syncLV(page1);
      await expect(readyButton).toHaveAttribute('aria-pressed', 'true');

      // User 2 sees the readiness marker in the participants list
      await expect(aliceReady).toHaveCount(1, { timeout: 5000 });

      // Clicking again withdraws it, for both users
      await readyButton.click();
      await syncLV(page1);
      await expect(readyButton).toHaveAttribute('aria-pressed', 'false');
      await expect(aliceReady).toHaveCount(0, { timeout: 5000 });

      // Mark ready again so the state-change cleanup below has something to clear
      await readyButton.click();
      await syncLV(page1);
      await expect(aliceReady).toHaveCount(1, { timeout: 5000 });

      // User 1 ends issue planning by clicking Back
      await page1.locator('button', { hasText: 'Back' }).click();
      await syncLV(page1);

      // Both users should be back to lobby
      await expect(page1.getByRole('heading', { name: 'Issues' })).toBeVisible();
      await expect(page2.getByRole('heading', { name: 'Issues' })).toBeVisible({ timeout: 10000 });

      // Readiness status should be cleared when the issue is left
      await expect(aliceReady).toHaveCount(0);
    } finally {
      await context1.close();
      await context2.close();
    }
  });

  test('section editing: lock visibility for other users', async ({ browser }) => {
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();
    const page1 = await context1.newPage();
    const page2 = await context2.newPage();

    try {
      // Both users login
      await loginAsMockUser(page1, 'alice');
      await loginAsMockUser(page2, 'bob');

      // Default mode is magic_estimation, so View buttons should already be visible
      await expect(page1.locator('button', { hasText: 'View' }).first()).toBeVisible({ timeout: 10000 });
      await expect(page2.locator('button', { hasText: 'View' }).first()).toBeVisible({ timeout: 10000 });

      // User 1 views an issue (first in list)
      await page1.locator('button', { hasText: 'View' }).first().click();
      await syncLV(page1);
      // User 2 should be on the same issue view via PubSub
      await expect(page2.getByRole('heading', { name: 'Voting' })).toBeVisible({ timeout: 10000 });

      // User 1 clicks Edit on a section
      await page1.locator('.section-wrapper').first().hover();
      await page1.locator('button', { hasText: 'Edit' }).first().click();
      await syncLV(page1);

      // User 2 should see the lock indicator (avatar with ping animation)
      await expect(page2.locator('.section-wrapper .animate-ping').first()).toBeVisible({ timeout: 5000 });

      // User 1 cancels the edit
      await page1.locator('button', { hasText: 'Cancel' }).click();
      await syncLV(page1);

      // User 2 should no longer see the lock
      await expect(page2.locator('.section-wrapper .animate-ping')).not.toBeVisible();
    } finally {
      await context1.close();
      await context2.close();
    }
  });

});
