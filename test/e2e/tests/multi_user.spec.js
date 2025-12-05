import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV, resetSession } from '../utils.js';

test.describe('Multi-user Planning Session', () => {

  test.beforeEach(async ({ request }) => {
    // Reset session before each test
    await resetSession(request);
  });

  test('readiness flow: select, sync, and clear on end', async ({ browser }) => {
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

      // Verify readiness controls are visible for User 1
      await expect(page1.getByRole('heading', { name: 'Your Readiness' })).toBeVisible();

      // User 1 selects readiness
      await page1.locator('button', { hasText: 'huh?' }).click();
      await syncLV(page1);

      // User 2 sees User 1's readiness in participants list
      const participantsPage2 = page2.locator('aside').filter({
        has: page2.getByRole('heading', { name: 'Participants' })
      });
      await expect(participantsPage2.locator('text=Alice')).toBeVisible();
      await expect(participantsPage2.locator('text=huh?')).toBeVisible({ timeout: 5000 });

      // User 1 ends issue planning by clicking Back
      await page1.locator('button', { hasText: 'Back' }).click();
      await syncLV(page1);

      // Both users should be back to lobby
      await expect(page1.getByRole('heading', { name: 'Issues' })).toBeVisible();
      await expect(page2.getByRole('heading', { name: 'Issues' })).toBeVisible({ timeout: 10000 });

      // Readiness status should be cleared
      await expect(participantsPage2.locator('text=huh?')).not.toBeVisible();
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
