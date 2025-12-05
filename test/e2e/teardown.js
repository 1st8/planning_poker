/**
 * Global teardown for Playwright e2e tests.
 * Gracefully stops the Phoenix server after all tests complete.
 */

import { request } from "@playwright/test";

export default async () => {
  try {
    const context = await request.newContext({
      baseURL: "http://localhost:4004",
    });
    // Gracefully stops the e2e server
    await context.post("/dev/halt");
  } catch {
    // Request may fail because server stops - this is expected
    return;
  }
};
