# Planning Poker

A real-time collaborative planning poker application for agile teams to estimate issues from various issue tracking systems.

## Purpose

Planning Poker is a Phoenix LiveView application that enables distributed teams to estimate the complexity and effort of issues in real-time. The application uses a pluggable adapter pattern to integrate with different issue providers (GitLab, Mock, etc.) and supports two estimation methodologies:

1. **Traditional Planning Poker**: Teams vote simultaneously on individual issues using story point cards, then reveal and discuss results
2. **Magic Estimation**: Teams collaboratively arrange issues in ascending order of complexity by dragging them between columns and placing story point markers

## Architecture Overview

### Core Components

**State Management (`lib/planning_poker/planning_session.ex`)**
- Implements `:gen_statem` behavior for managing planning session lifecycle
- Four distinct states: `:lobby`, `:voting`, `:results`, `:magic_estimation`
- Handles state transitions, vote collection, and issue management
- Integrates with `IssueProvider` adapter for asynchronous issue fetching
- Broadcasts state changes via `Phoenix.PubSub` for real-time updates

**LiveView Layer (`lib/planning_poker_web/live/planning_session_live/`)**
- `Show`: Main LiveView coordinating all components and handling events
- `LobbyComponent`: Displays issue list and controls for starting sessions
- `VotingComponent`: Interactive voting interface with story point cards
- `ResultsComponent`: Vote aggregation and reveal functionality
- `MagicEstimationComponent`: Drag-and-drop interface with sortable issue lists
- `ParticipantsListComponent`: Real-time participant presence tracking
- `VotingControlsComponent`: Session flow control buttons

**Issue Provider Adapters (`lib/planning_poker/issue_providers/`)**
- Pluggable adapter pattern for different issue tracking systems
- `IssueProvider` behavior defines common interface: `client/1`, `fetch_issues/2`, `fetch_issue/3`
- `Gitlab` adapter: Integrates with GitLab's GraphQL API, OAuth authentication
- `Mock` adapter: In-memory provider for local development, simple username-based "authentication"
- Configured via `ISSUE_PROVIDER` environment variable (defaults to `mock` in dev/test, `gitlab` in prod)

**Integration Points**
- Adapter-based authentication (GitLab OAuth or mock username selection)
- Issue fetching via configured provider adapter
- Phoenix Presence for tracking active participants in sessions
- Phoenix PubSub for broadcasting state changes to all connected clients

### Data Flow

1. Users authenticate via configured provider (GitLab OAuth receives access token, or mock direct login)
2. Planning session process starts as a supervised GenStatem process with auth token/credential
3. LiveView subscribes to session PubSub topic and monitors the session process
4. Session asynchronously fetches issues via configured IssueProvider adapter
5. State changes are broadcast to all connected LiveView clients
6. Participant presence is tracked and synchronized via Phoenix Presence

### Key Design Decisions

- **Adapter Pattern**: Issue provider abstraction allows seamless switching between GitLab, mock, and future providers (GitHub, Jira)
- **Stateful Sessions**: Each planning session runs as a separate supervised process, allowing independent session management and fault tolerance
- **Real-time Sync**: PubSub ensures all participants see the same state simultaneously
- **Async Issue Fetching**: API calls are offloaded to supervised tasks to prevent blocking the state machine
- **Component Architecture**: UI is split into focused LiveComponents for maintainability and reusability

### Local Development

For local development and testing, use the mock provider:

1. Set `ISSUE_PROVIDER=mock` in `config/.env.exs` (default in dev/test)
2. Start the application: `mix phx.server`
3. Login as mock users by visiting:
   - http://localhost:4000/auth/mock/alice
   - http://localhost:4000/auth/mock/bob
   - http://localhost:4000/auth/mock/carol
4. Open multiple browser windows/tabs to test collaboration features
5. Mock provider includes 6 sample issues with realistic content

### E2E Testing

End-to-end tests are located in `test/e2e/` and use Playwright:

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

#### E2E Test Architecture

**Shared Session Constraint**: The application has a single shared `PlanningSession` (GenStatem process) for all users. This means:
- Tests must run **sequentially** (not in parallel)
- Session state must be reset between tests
- Playwright is configured with `workers: 1` and `fullyParallel: false`

**Multi-User Testing**: Tests use separate browser contexts for each user to simulate multiple participants:
```javascript
const context1 = await browser.newContext();
const context2 = await browser.newContext();
const page1 = await context1.newPage();
const page2 = await context2.newPage();
```

**Dev Endpoints** (available in dev and e2e environments):
- `GET /dev/reset_session` - Kills the PlanningSession process to ensure clean state between tests
- `POST /dev/halt` - Gracefully shuts down the server (used by teardown.js)

**Test Utilities** (`test/e2e/utils.js`):
- `loginAsMockUser(page, username)` - Login as alice, bob, or carol
- `syncLV(page)` - Wait for LiveView to settle after events
- `resetSession(request)` - Call the reset endpoint before each test

**Global Teardown**: `test/e2e/teardown.js` calls `/dev/halt` after all tests complete to gracefully stop the Phoenix server. This prevents orphaned server processes.

**Test Structure**:
```javascript
test.beforeEach(async ({ request }) => {
  await resetSession(request);  // Clean slate for each test
});

test('multi-user scenario', async ({ browser }) => {
  // Create isolated contexts for each user
  const context1 = await browser.newContext();
  const page1 = await context1.newPage();
  // ... test logic
});
```

---

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps/phoenix/usage-rules/ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps/phoenix/usage-rules/elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps/phoenix/usage-rules/liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps/phoenix/usage-rules/phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- usage-rules-end -->
