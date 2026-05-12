import { test, expect } from '@playwright/test';
import { loginAsMockUser, syncLV, resetSession } from '../utils.js';

/**
 * End-to-end coverage for the magic auto-sort flow.
 *
 * The hint-collection design: each user types a number into the personal
 * notes textarea during voting (notes live in localStorage, not pushed to
 * the server during voting). When the session enters :magic_estimation
 * and a participant flips the Magic toggle on, the LiveView pushes a
 * `request_magic_hints` event to every connected client; the
 * MagicHintsResync hook responds with the localStorage hints filtered
 * to the issues currently in the magic estimation session. The server
 * aggregates them, computes per-issue consensus, and the UI renders
 * 🪄 wand badges or X/Y ghost badges accordingly. Apply-all places the
 * unanimous issues right after their target marker.
 */

const ISSUES = {
  one: 'mock-issue-1',
  two: 'mock-issue-2',
  three: 'mock-issue-3',
};

async function startVotingOn(page, issueId) {
  await page
    .locator(`button[phx-click="start_voting"][phx-value-issue_id="${issueId}"]`)
    .first()
    .click();
}

async function backToLobby(page) {
  await page.locator('button[phx-click="back_to_lobby"]').first().click();
}

/**
 * Have each participant vote on a single issue with their own value.
 * Pass `null` (or an empty string) for participants who should abstain —
 * their textarea is left untouched, and after the input handler debounce
 * elapses there is no localStorage entry for that issue.
 *
 * pages: array of { page, value } for each participant.
 */
async function voteOnIssue(pages, issueId) {
  const [{ page: driver }] = pages;
  await startVotingOn(driver, issueId);

  for (const { page } of pages) {
    await syncLV(page);
    await expect(page.locator(`#personal-notes-${issueId}`)).toBeVisible({
      timeout: 5000,
    });
  }

  for (const { page, value } of pages) {
    if (value === null || value === undefined || value === '') continue;
    await page.locator(`#personal-notes-${issueId}`).fill(String(value));
  }

  // Allow the 500 ms input-handler debounce to fire so localStorage is
  // committed (the handler schedules `saveNote` on a timer).
  for (const { page } of pages) {
    await syncLV(page, 700);
  }

  await backToLobby(driver);
  for (const { page } of pages) {
    await syncLV(page);
  }
}

async function startMagicEstimation(page) {
  await page.locator('button[phx-click="start_magic_estimation"]').first().click();
}

async function toggleMagicOn(page) {
  await page.locator('button[phx-click="toggle_magic"]').click();
}

async function assertNextAfterMarker(page, marker, issueId) {
  const children = page.locator('#estimated-issues .issue-list > *');
  const markerIdx = await children.evaluateAll(
    (nodes, m) => nodes.findIndex((n) => n.getAttribute('data-id') === m),
    marker,
  );
  expect(markerIdx, `marker ${marker} should be present in #estimated-issues`).toBeGreaterThan(-1);
  const nextId = await children.nth(markerIdx + 1).getAttribute('data-id');
  expect(nextId, `${issueId} should follow ${marker}`).toBe(issueId);

  await expect(
    page.locator(`.issue-card[data-id="${issueId}"][data-magic-applied="true"]`),
  ).toBeVisible();
}

async function loginNamed(browser, name) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await loginAsMockUser(page, name);
  return { ctx, page };
}

async function loginThree(browser) {
  const a = await loginNamed(browser, 'alice');
  const b = await loginNamed(browser, 'bob');
  const c = await loginNamed(browser, 'carol');

  for (const { page } of [a, b, c]) {
    await expect(page.getByRole('heading', { name: 'Issues' })).toBeVisible({
      timeout: 10000,
    });
  }

  return {
    pageA: a.page,
    pageB: b.page,
    pageC: c.page,
    cleanup: async () => {
      await a.ctx.close();
      await b.ctx.close();
      await c.ctx.close();
    },
  };
}

test.describe('Magic Auto-Sort', () => {
  test.beforeEach(async ({ request }) => {
    await resetSession(request);
  });

  test('three browsers, three unanimous issues, smart-sort places everything', async ({
    browser,
  }) => {
    const { pageA, pageB, pageC, cleanup } = await loginThree(browser);

    try {
      // Vote on three issues. Each participant types the same target value
      // for each issue → unanimous consensus on all three.
      await voteOnIssue(
        [
          { page: pageA, value: '5' },
          { page: pageB, value: '5' },
          { page: pageC, value: '5' },
        ],
        ISSUES.one,
      );
      await voteOnIssue(
        [
          { page: pageA, value: '8' },
          { page: pageB, value: '8' },
          { page: pageC, value: '8' },
        ],
        ISSUES.two,
      );
      await voteOnIssue(
        [
          { page: pageA, value: '3' },
          { page: pageB, value: '3' },
          { page: pageC, value: '3' },
        ],
        ISSUES.three,
      );

      // Move into magic estimation in all three browsers.
      await startMagicEstimation(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
          timeout: 10000,
        });
      }

      // Activate magic — server requests hints from each connected client,
      // each client pushes its localStorage hints filtered to the current
      // issue set, and consensus is computed.
      await toggleMagicOn(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }

      // All three browsers should now show wand badges with the consensus
      // values for each issue.
      const wandFor = (page, id) =>
        page.locator(`button[phx-click="apply_single_magic"][phx-value-issue-id="${id}"]`);

      for (const page of [pageA, pageB, pageC]) {
        await expect(wandFor(page, ISSUES.one)).toHaveText(/🪄\s*5/, { timeout: 5000 });
        await expect(wandFor(page, ISSUES.two)).toHaveText(/🪄\s*8/, { timeout: 5000 });
        await expect(wandFor(page, ISSUES.three)).toHaveText(/🪄\s*3/, { timeout: 5000 });
      }

      // Apply-all reads "Apply magic (3)".
      const applyAll = pageA.locator('button[phx-click="apply_all_magic"]');
      await expect(applyAll).toBeVisible();
      await expect(applyAll).toContainText('Apply magic (3)');

      // force:true bypasses Playwright's actionability checks; without it,
      // the LV's transient phx-click-loading state on the button keeps
      // the click pending past the test timeout.
      await applyAll.click({ force: true });
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }

      // Each issue lands right after its matching marker in every browser.
      for (const page of [pageA, pageB, pageC]) {
        await assertNextAfterMarker(page, 'marker/5', ISSUES.one);
        await assertNextAfterMarker(page, 'marker/8', ISSUES.two);
        await assertNextAfterMarker(page, 'marker/3', ISSUES.three);
      }

      const pill = pageA.locator('[aria-label="Magic estimation progress"]');
      await expect(pill).toContainText(/3\/\d+\s*magically estimated/);
    } finally {
      await cleanup();
    }
  });

  test('mixed agreement — only the unanimous issue is auto-placed', async ({ browser }) => {
    const { pageA, pageB, pageC, cleanup } = await loginThree(browser);

    try {
      // Consensus in this codebase = "every participant submitted a parseable
      // hint" (mean → nearest marker). It does NOT require all values to
      // match. So to land in the :pending / X/Y-ghost branch we need at
      // least one participant to abstain (empty textarea = no localStorage
      // entry = treated as missing).

      // Issue 1: all three submit "3" → ready, target marker/3.
      await voteOnIssue(
        [
          { page: pageA, value: '3' },
          { page: pageB, value: '3' },
          { page: pageC, value: '3' },
        ],
        ISSUES.one,
      );

      // Issue 2: carol abstains, alice/bob submit "5" → 2/3 ghost.
      await voteOnIssue(
        [
          { page: pageA, value: '5' },
          { page: pageB, value: '5' },
          { page: pageC, value: null },
        ],
        ISSUES.two,
      );

      // Issue 3: alice abstains, bob/carol submit "13" → 2/3 ghost.
      await voteOnIssue(
        [
          { page: pageA, value: null },
          { page: pageB, value: '13' },
          { page: pageC, value: '13' },
        ],
        ISSUES.three,
      );

      await startMagicEstimation(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
          timeout: 10000,
        });
      }

      await toggleMagicOn(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 600);
      }

      const wandFor = (page, id) =>
        page.locator(`button[phx-click="apply_single_magic"][phx-value-issue-id="${id}"]`);
      const ghostFor = (page, id) =>
        page.locator(`.issue-card[data-id="${id}"] .badge.badge-ghost`);

      for (const page of [pageA, pageB, pageC]) {
        await expect(wandFor(page, ISSUES.one)).toHaveText(/🪄\s*3/, { timeout: 5000 });
        await expect(ghostFor(page, ISSUES.two)).toHaveText(/2\/3/);
        await expect(ghostFor(page, ISSUES.three)).toHaveText(/2\/3/);
      }

      const applyAll = pageA.locator('button[phx-click="apply_all_magic"]');
      await expect(applyAll).toContainText('Apply magic (1)');

      await applyAll.click({ force: true });
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }

      // Only issue 1 was placed.
      for (const page of [pageA, pageB, pageC]) {
        await assertNextAfterMarker(page, 'marker/3', ISSUES.one);

        const ids = await page
          .locator('#unestimated-issues .issue-list > *')
          .evaluateAll((nodes) => nodes.map((n) => n.getAttribute('data-id')));
        expect(ids).toContain(ISSUES.two);
        expect(ids).toContain(ISSUES.three);
        expect(ids).not.toContain(ISSUES.one);
      }

      const pill = pageA.locator('[aria-label="Magic estimation progress"]');
      await expect(pill).toContainText(/1\/\d+\s*magically estimated/);
    } finally {
      await cleanup();
    }
  });

  test('late joiner triggers request_magic_hints on mount', async ({ browser }) => {
    // Two users vote with consensus and activate magic. A third user joins
    // after magic is already on. The mount-time request_magic_hints in
    // show.ex sees state == :magic_estimation && magic.enabled and pushes
    // the request to the late joiner's hook. They have nothing in
    // localStorage, so they push an empty hints map. Once :sync_turn_order
    // adds them to turn_order, consensus drops from ready to 2/3 ghost.
    const a = await loginNamed(browser, 'alice');
    const b = await loginNamed(browser, 'bob');

    for (const { page } of [a, b]) {
      await expect(page.getByRole('heading', { name: 'Issues' })).toBeVisible({
        timeout: 10000,
      });
    }

    let carol;
    try {
      await voteOnIssue(
        [
          { page: a.page, value: '5' },
          { page: b.page, value: '5' },
        ],
        ISSUES.one,
      );

      await startMagicEstimation(a.page);
      for (const { page } of [a, b]) {
        await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
          timeout: 10000,
        });
      }

      await toggleMagicOn(a.page);
      for (const { page } of [a, b]) {
        await syncLV(page, 800);
      }

      const wandFor = (page, id) =>
        page.locator(`button[phx-click="apply_single_magic"][phx-value-issue-id="${id}"]`);
      for (const { page } of [a, b]) {
        await expect(wandFor(page, ISSUES.one)).toHaveText(/🪄\s*5/, { timeout: 5000 });
      }

      // Carol joins now — magic is already on. The connected mount path
      // emits request_magic_hints to her, she pushes empty hints, and
      // consensus loses unanimity once she's added to turn_order.
      carol = await loginNamed(browser, 'carol');
      await expect(carol.page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
        timeout: 10000,
      });
      for (const { page } of [a, b, carol]) {
        await syncLV(page, 800);
      }

      const ghostFor = (page, id) =>
        page.locator(`.issue-card[data-id="${id}"] .badge.badge-ghost`);
      for (const { page } of [a, b, carol]) {
        await expect(ghostFor(page, ISSUES.one)).toHaveText(/2\/3/, { timeout: 5000 });
        await expect(wandFor(page, ISSUES.one)).not.toBeVisible();
      }
    } finally {
      await a.ctx.close();
      await b.ctx.close();
      if (carol) await carol.ctx.close();
    }
  });

  test('toggle off → on again re-fires request and consensus reappears', async ({ browser }) => {
    const { pageA, pageB, pageC, cleanup } = await loginThree(browser);

    try {
      await voteOnIssue(
        [
          { page: pageA, value: '5' },
          { page: pageB, value: '5' },
          { page: pageC, value: '5' },
        ],
        ISSUES.one,
      );

      await startMagicEstimation(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
          timeout: 10000,
        });
      }

      const wandFor = (page, id) =>
        page.locator(`button[phx-click="apply_single_magic"][phx-value-issue-id="${id}"]`);
      const toggle = pageA.locator('button[phx-click="toggle_magic"]');

      // First on — wand badge appears.
      await toggle.click();
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }
      for (const page of [pageA, pageB, pageC]) {
        await expect(wandFor(page, ISSUES.one)).toHaveText(/🪄\s*5/, { timeout: 5000 });
      }

      // Off — wand badge hidden (UI gates consensus on magic.enabled).
      await toggle.click();
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 400);
      }
      for (const page of [pageA, pageB, pageC]) {
        await expect(wandFor(page, ISSUES.one)).not.toBeVisible();
      }

      // On again — request_magic_hints fires a second time, hints come
      // back, wand badge reappears.
      await toggle.click();
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }
      for (const page of [pageA, pageB, pageC]) {
        await expect(wandFor(page, ISSUES.one)).toHaveText(/🪄\s*5/, { timeout: 5000 });
      }
    } finally {
      await cleanup();
    }
  });

  test('issue_ids filter excludes stale localStorage; "?" parses as abstain', async ({
    browser,
  }) => {
    const { pageA, pageB, pageC, cleanup } = await loginThree(browser);

    try {
      // Inject stale localStorage entries for issue ids that aren't in the
      // current magic-estimation session. They must NOT make it to the
      // server because the request_magic_hints payload restricts the hook
      // to the current id set.
      await pageB.evaluate(() => {
        const key = 'planning_poker_notes_mock-user-bob';
        localStorage.setItem(
          key,
          JSON.stringify({
            'mock-issue-1': '5',
            'old-issue-99': '999',
            'garbage-id': '42',
          }),
        );
      });

      // Alice writes "?" → abstain. Bob already has localStorage for issue 1.
      // Carol types "5" normally.
      await voteOnIssue(
        [
          { page: pageA, value: '?' },
          { page: pageB, value: null }, // skip — bob's localStorage already has '5' for issue 1
          { page: pageC, value: '5' },
        ],
        ISSUES.one,
      );

      await startMagicEstimation(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
          timeout: 10000,
        });
      }

      await toggleMagicOn(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }

      // Alice abstained ("?" parses as :abstain), so consensus on issue 1
      // is :pending → 2/3 ghost. Stale localStorage keys for issues that
      // don't exist in the session are not represented anywhere.
      const ghostFor = (page, id) =>
        page.locator(`.issue-card[data-id="${id}"] .badge.badge-ghost`);
      const wandFor = (page, id) =>
        page.locator(`button[phx-click="apply_single_magic"][phx-value-issue-id="${id}"]`);

      for (const page of [pageA, pageB, pageC]) {
        await expect(ghostFor(page, ISSUES.one)).toHaveText(/2\/3/, { timeout: 5000 });
        await expect(wandFor(page, ISSUES.one)).not.toBeVisible();
      }

      // No card or badge renders for the fake ids — they aren't part of
      // the session at all.
      for (const fakeId of ['old-issue-99', 'garbage-id']) {
        await expect(pageA.locator(`.issue-card[data-id="${fakeId}"]`)).toHaveCount(0);
      }
    } finally {
      await cleanup();
    }
  });

  test('back_to_lobby fired inside debounce window still persists notes', async ({ browser }) => {
    // Regression: real teams often click back_to_lobby the instant a slow
    // typist finishes — well inside the PersonalIssueNotes debounce window.
    // localStorage must already be written synchronously on every keystroke,
    // otherwise destroyed() cancels the pending timer and the typed value is
    // silently dropped (producing "0/N" badges on every issue for every
    // user).
    const { pageA, pageB, pageC, cleanup } = await loginThree(browser);

    try {
      for (const issueId of [ISSUES.one, ISSUES.two, ISSUES.three]) {
        await startVotingOn(pageA, issueId);
        for (const page of [pageA, pageB, pageC]) {
          await expect(page.locator(`#personal-notes-${issueId}`)).toBeVisible({
            timeout: 5000,
          });
        }
        for (const page of [pageA, pageB, pageC]) {
          const ta = page.locator(`#personal-notes-${issueId}`);
          await ta.click();
          await ta.press('5');
        }
        // 50 ms is well under the 500 ms PersonalIssueNotes sync debounce —
        // any persistence relying on that debounce will be cancelled when
        // back_to_lobby unmounts the textarea.
        await pageA.waitForTimeout(50);
        await backToLobby(pageA);
        for (const page of [pageA, pageB, pageC]) {
          await syncLV(page, 200);
        }
      }

      await startMagicEstimation(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await expect(page.getByRole('heading', { name: 'Magic Estimation' })).toBeVisible({
          timeout: 10000,
        });
      }

      await toggleMagicOn(pageA);
      for (const page of [pageA, pageB, pageC]) {
        await syncLV(page, 800);
      }

      const wandFor = (page, id) =>
        page.locator(`button[phx-click="apply_single_magic"][phx-value-issue-id="${id}"]`);

      for (const page of [pageA, pageB, pageC]) {
        await expect(wandFor(page, ISSUES.one)).toHaveText(/🪄\s*5/, { timeout: 5000 });
        await expect(wandFor(page, ISSUES.two)).toHaveText(/🪄\s*5/, { timeout: 5000 });
        await expect(wandFor(page, ISSUES.three)).toHaveText(/🪄\s*5/, { timeout: 5000 });
      }
    } finally {
      await cleanup();
    }
  });
});
