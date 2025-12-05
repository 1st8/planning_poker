import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV, resetSession } from '../utils.js';

test.describe('Magic Estimation Turn-Based Mode', () => {

  test.beforeEach(async ({ request }) => {
    await resetSession(request);
  });

  test('turn-based workflow: control, handoff, highlighting, and disconnect', async ({ browser }) => {
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();
    const page1 = await context1.newPage();
    const page2 = await context2.newPage();

    try {
      // === SETUP: Both users login ===
      await loginAsMockUser(page1, 'alice');
      await loginAsMockUser(page2, 'bob');

      await expect(page1.getByRole('heading', { name: 'Issues' })).toBeVisible({ timeout: 10000 });
      await expect(page2.getByRole('heading', { name: 'Issues' })).toBeVisible({ timeout: 10000 });

      // Start magic estimation
      await page1.locator('button', { hasText: 'Magic Estimation' }).click();
      await syncLV(page1);

      await expect(page1.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({ timeout: 10000 });
      await expect(page2.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({ timeout: 10000 });

      // === TEST 1: Turn order and control ===
      // Check that exactly one user is active
      const page1IsTurn = await page1.locator('text=Du bist dran!').isVisible();
      const page2IsTurn = await page2.locator('text=Du bist dran!').isVisible();

      expect(page1IsTurn || page2IsTurn).toBe(true);
      expect(page1IsTurn && page2IsTurn).toBe(false);

      // Active user sees "Bin fertig" button, other doesn't
      let activePage = page1IsTurn ? page1 : page2;
      let waitingPage = page1IsTurn ? page2 : page1;

      await expect(activePage.locator('#end-turn-btn')).toBeVisible();
      await expect(waitingPage.locator('#end-turn-btn')).not.toBeVisible();

      // Active participant is highlighted
      await expect(page1.locator('.participant-active')).toBeVisible();
      await expect(page1.locator('.badge:has-text("dran")')).toBeVisible();

      // === TEST 2: Drag issue and verify highlighting after handoff ===
      // Get the first issue card
      const issueCard = activePage.locator('#unestimated-issues .issue-card').first();
      const issueId = await issueCard.getAttribute('data-id');

      // Drag issue to estimated column
      const targetColumn = activePage.locator('#estimated-issues .sortable-list');
      const sourceBox = await issueCard.boundingBox();
      const targetBox = await targetColumn.boundingBox();

      await activePage.mouse.move(sourceBox.x + sourceBox.width / 2, sourceBox.y + sourceBox.height / 2);
      await activePage.mouse.down();
      await activePage.mouse.move(targetBox.x + targetBox.width / 2, targetBox.y + 50, { steps: 10 });
      await activePage.mouse.up();
      await syncLV(activePage, 500);

      // Verify issue moved
      await expect(activePage.locator(`#estimated-issues .issue-card[data-id="${issueId}"]`)).toBeVisible({ timeout: 5000 });

      // === TEST 3: Turn handoff ===
      await activePage.locator('#end-turn-btn').click();
      await syncLV(activePage, 500);
      await syncLV(waitingPage, 500);

      // Control should have passed
      await expect(waitingPage.locator('text=Du bist dran!')).toBeVisible({ timeout: 5000 });
      await expect(activePage.locator('text=ist dran...')).toBeVisible({ timeout: 5000 });
      await expect(waitingPage.locator('#end-turn-btn')).toBeVisible();
      await expect(activePage.locator('#end-turn-btn')).not.toBeVisible();

      // Moved issue should be highlighted for new active user
      const movedIssue = waitingPage.locator(`.issue-card[data-id="${issueId}"]`);
      await expect(movedIssue).toHaveClass(/moved-last-turn/, { timeout: 5000 });

      // === TEST 4: Disconnect auto-advance ===
      // Swap references since control changed
      const nowActivePage = waitingPage;
      const nowWaitingPage = activePage;
      const nowActiveContext = page1IsTurn ? context2 : context1;
      const remainingPage = nowWaitingPage;

      // Close the now-active user's context
      await nowActiveContext.close();
      await syncLV(remainingPage, 500);

      // Remaining user should become active
      await expect(remainingPage.locator('text=Du bist dran!')).toBeVisible({ timeout: 5000 });

    } finally {
      try { await context1.close(); } catch (e) { /* already closed */ }
      try { await context2.close(); } catch (e) { /* already closed */ }
    }
  });

});
