import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV } from '../utils.js';

test.describe('Main Planning Poker Workflow', () => {
  test('complete workflow: login, load issues, view issue, start magic estimation', async ({ page }) => {
    // Step 1: Mock login works
    await loginAsMockUser(page, 'alice');

    // Verify login succeeded - we should see Alice in participants
    await expect(page.locator('text=Alice')).toBeVisible();

    // Step 2: Issues are loaded
    // Verify we're in the lobby
    await expect(page.getByRole('heading', { name: 'Issues' })).toBeVisible();

    // Verify all 6 mock issues are displayed
    const issuesList = page.locator('li').filter({ hasText: 'planning-poker#' });
    await expect(issuesList).toHaveCount(6);

    // Verify specific issue titles are present
    await expect(page.locator('text=Add user profile page')).toBeVisible();
    await expect(page.locator('text=Fix login page styling on mobile')).toBeVisible();
    await expect(page.locator('text=Implement real-time notifications')).toBeVisible();
    await expect(page.locator('text=Refactor database queries for performance')).toBeVisible();
    await expect(page.locator('text=Add keyboard shortcuts')).toBeVisible();
    await expect(page.locator('text=Export planning session results')).toBeVisible();

    // Verify issue references are displayed correctly
    for (let i = 1; i <= 6; i++) {
      await expect(page.locator(`text=planning-poker#${i}`)).toBeVisible();
    }

    // Step 3: Issues can be viewed
    // Click the View button for the first issue
    await page
      .locator('li')
      .filter({ hasText: 'Add user profile page' })
      .locator('button', { hasText: 'View' })
      .click();

    await syncLV(page);

    // Verify we're now in voting view
    await expect(page.getByRole('heading', { name: 'Voting' })).toBeVisible();

    // Verify issue title and details are displayed
    await expect(page.getByRole('heading', { name: 'User Profile Page', exact: true })).toBeVisible();
    await expect(page.locator('text=Users should be able to view and edit their profile information')).toBeVisible();

    // Verify Requirements section
    await expect(page.getByRole('heading', { name: 'Requirements' })).toBeVisible();
    await expect(page.locator('text=Display user name, email, avatar')).toBeVisible();

    // Verify Acceptance Criteria section
    await expect(page.getByRole('heading', { name: 'Acceptance Criteria' })).toBeVisible();
    await expect(page.locator('text=Profile page loads correctly')).toBeVisible();

    // Navigate back to lobby
    await page.locator('button', { hasText: 'Back' }).click();
    await syncLV(page);

    // Verify we're back in lobby
    await expect(page.getByRole('heading', { name: 'Issues' })).toBeVisible();

    // Step 4: Magic estimation can be started
    // Click "Start Magic Estimation" button
    await page.locator('button', { hasText: 'Start Magic Estimation' }).click();
    await syncLV(page);

    // Verify we're in magic estimation mode
    await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible();

    // Verify "Unestimated Issues" column is visible
    await expect(page.getByRole('heading', { name: 'Unestimated Issues' })).toBeVisible();

    // Verify "Estimated Issues" column is visible
    await expect(page.getByRole('heading', { name: /Estimated Issues/ })).toBeVisible();

    // Verify all 6 issues are in the unestimated column
    const unestimatedIssues = page.locator('text=planning-poker#');
    await expect(unestimatedIssues).toHaveCount(6);

    // Verify story point markers are displayed
    const markers = ['1', '2', '3', '5', '8', '13', '21'];
    for (const marker of markers) {
      await expect(page.locator(`text="${marker}"`).first()).toBeVisible();
    }

    // Verify the complete button is visible
    await expect(page.locator('button', { hasText: 'Press and hold to complete' })).toBeVisible();
  });
});
