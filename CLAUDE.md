# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PlanningPoker is a Phoenix LiveView application for conducting agile planning sessions. It integrates with GitLab to fetch issues and supports two estimation modes: traditional Planning Poker and Magic Estimation.

## Development Commands

### Setup
```bash
mix setup                 # Install dependencies and build assets
mix deps.get              # Install Elixir dependencies
mix assets.setup          # Install Tailwind and esbuild
mix assets.build          # Build assets
```

### Running the Application
```bash
mix phx.server            # Start Phoenix server (dev mode)
iex -S mix phx.server     # Start with interactive shell
```

### Testing
```bash
mix test                  # Run all tests
mix test test/path/to/specific_test.exs  # Run specific test file
mix test test/path/to/specific_test.exs:42  # Run specific test at line 42
```

### Asset Management
```bash
mix assets.deploy         # Build and minify assets for production
```

### Docker
```bash
docker build -t planning_poker .
docker run -p 4000:4000 -e SECRET_KEY_BASE=... -e GITLAB_CLIENT_ID=... planning_poker
```

## Architecture

### State Management with gen_statem

The core of the application is `PlanningPoker.PlanningSession` (lib/planning_poker/planning_session.ex:1), which uses Erlang's `:gen_statem` behavior to manage planning sessions as state machines with four states:

- **:lobby** - Initial state where issues are loaded and mode is selected
- **:voting** - Traditional planning poker voting on a single issue
- **:results** - Display voting results
- **:magic_estimation** - Drag-and-drop estimation mode with story point markers

State transitions are triggered by events (e.g., `start_voting`, `finish_voting`) and broadcast to all participants via Phoenix.PubSub.

### Session Management

Planning sessions are:
- Started on-demand via `PlanningPoker.Planning.ensure_started/2` (lib/planning_poker/planning.ex:4)
- Registered in a Registry for process discovery (lib/planning_poker/application.ex:18)
- Long-lived processes that persist across participant connections
- Accessed via `Planning.to_pid/1` helper which looks up the process by session ID

### Real-time Communication

The application uses two Phoenix real-time mechanisms:

1. **Phoenix.PubSub** - For broadcasting session state changes to all participants
   - Topic format: `"planning_sessions:#{session_id}"`
   - Used for state transitions, issue updates

2. **Phoenix.Presence** - For tracking participant presence and votes
   - Participants join via `Planning.join_participant/2` (lib/planning_poker/planning.ex:16)
   - Votes stored as metadata in Presence tracking
   - Presence updates trigger `presence_diff` events in LiveView

### LiveView Architecture

`PlanningPokerWeb.PlanningSessionLive.Show` (lib/planning_poker_web/live/planning_session_live/show.ex:1) is the main LiveView that:
- Monitors the planning session process (dies if session crashes)
- Subscribes to PubSub for state changes
- Tracks Presence for participant updates
- Renders different components based on session state

Components are organized by state:
- `LobbyComponent` - Issue selection and mode switching
- `VotingComponent` - Card selection for planning poker
- `ResultsComponent` - Display vote results
- `MagicEstimationComponent` - Drag-and-drop interface
- `ParticipantsListComponent` - Show connected users

### GitLab Integration

`PlanningPoker.GitlabApi` (lib/planning_poker/gitlab_api.ex:1) uses GraphQL to:
- Fetch issues from a GitLab board list (configured via `DEFAULT_LIST_ID` env var)
- Filter for unestimated issues (weight: None)
- Retrieve full issue details including description, epic, author

Authentication uses Ueberauth with GitLab OAuth strategy. The token is stored in the session and passed to the planning session GenStatem for API calls.

### Async Task Handling

Issue fetching is async to avoid blocking the state machine:
- Uses `Task.Supervisor.async_nolink/2` (lib/planning_poker/planning_session.ex:237)
- Stores task ref in state (`:fetch_issues_ref`, `:fetch_issue_ref`)
- Handles results via info messages (lib/planning_poker/planning_session.ex:179)
- Broadcasts updated state when async tasks complete

## Key Configuration

Required environment variables:
- `SECRET_KEY_BASE` - Phoenix secret (generate with `mix phx.gen.secret`)
- `GITLAB_CLIENT_ID` and `GITLAB_CLIENT_SECRET` - OAuth credentials
- `PHX_HOST` - Host for URL generation (default: `example.com`)
- `DEFAULT_LIST_ID` - GitLab board list ID for fetching issues

See config/runtime.exs:1 for full configuration details.

## Important Implementation Notes

### Vote Clearing
When committing results, votes are cleared by iterating through all Presence entries and updating each participant's metadata to remove the `:vote` key (lib/planning_poker/planning.ex:55).

### Magic Estimation
Story point markers are dynamically created from the options list, excluding "?" (lib/planning_poker/planning_session.ex:85). Issues and markers can be dragged between "unestimated" and "estimated" lists, with position tracked via index.

### Session Recovery
LiveViews monitor the planning session process. If the session crashes, the LiveView displays an error and terminates itself (lib/planning_poker_web/live/planning_session_live/show.ex:121).
