import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV } from '../utils.js';

test.describe('Readiness Controls', () => {
  test('can select and switch readiness status in magic estimation', async ({ page }) => {
    // Step 1: Login as Alice
    await loginAsMockUser(page, 'alice');

    // Verify login succeeded
    await expect(page.locator('text=Alice')).toBeVisible();

    // Step 2: Start Magic Estimation
    await expect(page.locator('button', { hasText: 'Start Magic Estimation' })).toBeVisible();
    await page.locator('button', { hasText: 'Start Magic Estimation' }).click();
    await syncLV(page);

    // Verify we're in magic estimation mode
    await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible();

    // Step 3: Verify Readiness Controls are visible
    await expect(page.getByRole('heading', { name: 'Your Readiness' })).toBeVisible();

    // Verify all 5 readiness buttons are present
    await expect(page.locator('button', { hasText: 'huh?' })).toBeVisible();
    await expect(page.locator('button', { hasText: 'umm...' })).toBeVisible();
    await expect(page.locator('button', { hasText: 'okay I guess' })).toBeVisible();
    await expect(page.locator('button', { hasText: 'pretty clear' })).toBeVisible();
    await expect(page.locator('button', { hasText: '10/10 got it' })).toBeVisible();

    // Step 4: Select a readiness status (confused)
    await page.locator('button', { hasText: 'huh?' }).click();
    await syncLV(page);

    // Step 5: Verify the status appears in the participants list
    // Look for Alice's name and the readiness status below it
    const participantsList = page.locator('aside').filter({ has: page.getByRole('heading', { name: 'Participants' }) });
    await expect(participantsList.locator('text=Alice')).toBeVisible();
    await expect(participantsList.locator('text=🤔 huh?')).toBeVisible();

    // Verify the button is highlighted as active
    const confusedButton = page.locator('button', { hasText: 'huh?' });
    await expect(confusedButton).toHaveClass(/btn-active/);

    // Step 6: Switch to a different status (totally clear)
    await page.locator('button', { hasText: '10/10 got it' }).click();
    await syncLV(page);

    // Step 7: Verify the new status is displayed
    await expect(participantsList.locator('text=🎯 10/10 got it')).toBeVisible();

    // Verify the old status is no longer shown
    await expect(participantsList.locator('text=🤔 huh?')).not.toBeVisible();

    // Verify the new button is highlighted as active
    const clearButton = page.locator('button', { hasText: '10/10 got it' });
    await expect(clearButton).toHaveClass(/btn-active/);

    // Verify the previous button is no longer active
    await expect(confusedButton).not.toHaveClass(/btn-active/);
  });

});
