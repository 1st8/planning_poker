/**
 * E2E Test Utilities for Phoenix LiveView
 */

/**
 * Wait for LiveView to finish processing all events.
 * Call this after triggering actions to ensure the view has updated.
 *
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {number} timeout - Maximum time to wait in milliseconds (default: 5000)
 */
export async function syncLV(page, timeout = 5000) {
  // Just wait a short time for LiveView to process events
  await page.waitForTimeout(300);
}

/**
 * Wait for LiveView connection to be established.
 *
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {number} timeout - Maximum time to wait in milliseconds (default: 10000)
 */
export async function waitForLiveView(page, timeout = 10000) {
  await page.waitForFunction(
    () => {
      return window.liveSocket && window.liveSocket.isConnected();
    },
    { timeout }
  );
}

/**
 * Login as a mock user.
 *
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {string} username - Mock username (alice, bob, or carol)
 */
export async function loginAsMockUser(page, username) {
  await page.goto(`/auth/mock/${username}`);
  await waitForLiveView(page);
  await syncLV(page);
}

/**
 * Navigate to the planning session lobby.
 *
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {string} sessionId - Session ID (default: 'default')
 */
export async function navigateToLobby(page, sessionId = 'default') {
  await page.goto(`/${sessionId}`);
  await waitForLiveView(page);
  await syncLV(page);
}

/**
 * Wait for an element to appear with text content.
 *
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {string} selector - CSS selector
 * @param {string} text - Text to wait for
 * @param {number} timeout - Maximum time to wait in milliseconds (default: 5000)
 */
export async function waitForText(page, selector, text, timeout = 5000) {
  await page.waitForSelector(`${selector}:has-text("${text}")`, { timeout });
}
