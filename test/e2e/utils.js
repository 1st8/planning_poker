/**
 * E2E Test Utilities for Phoenix LiveView
 */

/**
 * Wait for LiveView to finish processing all events.
 * Simple wait for DOM to settle after LiveView events.
 *
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {number} timeout - Maximum time to wait in milliseconds (default: 300)
 */
export async function syncLV(page, timeout = 300) {
  // Simple wait for DOM updates to complete
  await page.waitForTimeout(timeout);
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

/**
 * Reset the planning session by calling the dev endpoint.
 * This kills the GenStatem process to ensure clean state between tests.
 *
 * @param {import('@playwright/test').APIRequestContext} request - Playwright request context
 */
export async function resetSession(request) {
  await request.get('/dev/reset_session');
  // Give server time to clean up
  await new Promise(r => setTimeout(r, 100));
}
