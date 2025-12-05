# E2E Tests

End-to-end tests using Playwright for the Planning Poker application.

## Running Tests

```bash
# Run all e2e tests
npm run e2e:test

# Run a specific test file
npm run e2e:test -- multi_user.spec.js

# Run tests with UI (interactive mode)
npm run e2e:ui

# Run tests in headed mode (see browser)
npm run e2e:headed

# Debug tests (step through with debugger)
npm run e2e:debug
```

Tests automatically start the Phoenix server on port 4004 in e2e mode.

## Architecture

### Shared Session Constraint

The application has a single shared `PlanningSession` (GenStatem process) for all users. This means:
- Tests must run **sequentially** (not in parallel)
- Session state must be reset between tests
- Playwright is configured with `workers: 1` and `fullyParallel: false`

### Multi-User Testing

Tests use separate browser contexts for each user to simulate multiple participants with isolated sessions (cookies, storage):

```javascript
const context1 = await browser.newContext();
const context2 = await browser.newContext();
const page1 = await context1.newPage();
const page2 = await context2.newPage();

await loginAsMockUser(page1, 'alice');
await loginAsMockUser(page2, 'bob');
```

### Dev Endpoints

Available in dev and e2e environments (`config/e2e.exs` sets `dev_routes: true`):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/dev/reset_session` | GET | Kills the PlanningSession process to ensure clean state between tests |
| `/dev/halt` | POST | Gracefully shuts down the server (used by teardown.js) |

### Test Utilities

Located in `utils.js`:

- `loginAsMockUser(page, username)` - Login as alice, bob, or carol
- `syncLV(page)` - Wait for LiveView to settle after events
- `resetSession(request)` - Call the reset endpoint before each test
- `waitForLiveView(page)` - Wait for LiveView websocket connection
- `navigateToLobby(page)` - Navigate to the planning session lobby

### Global Teardown

`teardown.js` calls `/dev/halt` after all tests complete to gracefully stop the Phoenix server. This prevents orphaned server processes between test runs.

## Test Structure

```javascript
import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV, resetSession } from '../utils.js';

test.describe('Feature', () => {
  test.beforeEach(async ({ request }) => {
    await resetSession(request);  // Clean slate for each test
  });

  test('multi-user scenario', async ({ browser }) => {
    // Create isolated contexts for each user
    const context1 = await browser.newContext();
    const context2 = await browser.newContext();
    const page1 = await context1.newPage();
    const page2 = await context2.newPage();

    try {
      await loginAsMockUser(page1, 'alice');
      await loginAsMockUser(page2, 'bob');

      // Test actions...
      await page1.locator('button', { hasText: 'View' }).first().click();
      await syncLV(page1);

      // Verify on other user's page
      await expect(page2.getByRole('heading', { name: 'Voting' })).toBeVisible();
    } finally {
      await context1.close();
      await context2.close();
    }
  });
});
```

## File Structure

```
test/e2e/
├── playwright.config.js   # Playwright configuration
├── teardown.js            # Global teardown (stops server)
├── test_helper.exs        # Elixir script to start Phoenix server
├── utils.js               # Shared test utilities
├── README.md              # This file
└── tests/
    └── multi_user.spec.js # Multi-user test scenarios
```
