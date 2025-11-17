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
- `AudioRecorderComponent`: Voice comment recording with automatic transcription (GitLab only)

**Audio Transcription System (`lib/planning_poker/audio_transcription/`)**
- `ModelServer`: Lazy-loading GenServer for Whisper AI model management
  - Downloads model once (~290MB) to `~/.cache/huggingface/`
  - Keeps model in memory for 30 minutes after last use
  - Automatically unloads to conserve memory during idle periods
- `Worker`: Background transcription workflow orchestrator
  - Processes audio files via Task.Supervisor
  - Transcribes using Whisper (openai/whisper-base)
  - Posts transcriptions to GitLab issues as comments
  - Handles errors gracefully with user feedback
- `FileCleanup`: Delayed audio file cleanup service
  - Schedules files for deletion 2 hours after transcription
  - Allows debugging and potential re-processing
  - Tracks scheduled cleanups and handles errors

**Issue Provider Adapters (`lib/planning_poker/issue_providers/`)**
- Pluggable adapter pattern for different issue tracking systems
- `IssueProvider` behavior defines common interface: `client/1`, `fetch_issues/2`, `fetch_issue/3`, `update_issue/4`, `post_comment/4`
- `Gitlab` adapter: Integrates with GitLab's GraphQL API and REST API
  - Uses GraphQL for fetching issues
  - Uses REST API for updating issues and posting comments
  - OAuth authentication with `api` scope required
- `Mock` adapter: In-memory provider for local development
  - Simple username-based "authentication"
  - Simulates all GitLab API operations including comment posting
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
npm run e2e:test -- readiness_controls.spec.js

# Run tests with UI (interactive mode)
npm run e2e:ui

# Run tests in headed mode (see browser)
npm run e2e:headed

# Debug tests (step through with debugger)
npm run e2e:debug
```

Tests automatically start the Phoenix server on port 4004 in e2e mode.

### Voice Comments with Audio Transcription

The application supports recording voice comments during planning sessions, which are automatically transcribed and posted to GitLab issues.

**Feature Overview:**
- Available during voting/planning mode (GitLab provider only)
- Records audio directly in the browser using MediaRecorder API
- Transcribes audio using OpenAI Whisper (base model)
- Posts transcription as a comment to the current GitLab issue
- Automatically cleans up audio files after 2 hours

**Usage:**
1. Navigate to a planning session and start voting on an issue
2. Click "Kommentar aufnehmen" (Record Comment) button
3. Grant microphone access when prompted
4. Record your voice comment (up to 10 minutes, 50MB max)
5. Click "Stop" when finished
6. Review the duration, then click "Senden" (Send)
7. Wait for transcription to complete (~5-30 seconds depending on length)
8. Transcription will be posted to the GitLab issue automatically

**Technical Details:**
- **Audio Formats Supported**: WebM/Opus (preferred), OGG/Opus, MP4, MPEG, WAV
- **Whisper Model**: `openai/whisper-base` (~290MB, good balance of speed/accuracy)
- **Model Caching**: Downloads once to `~/.cache/huggingface/`, stays in memory for 30 min
- **File Storage**: Temporary files in `priv/static/uploads/audio/{session_id}/`
- **Cleanup**: Files deleted 2 hours after transcription
- **Languages**: Whisper supports 97 languages automatically

**Configuration:**

Audio transcription settings in `config/config.exs`:

```elixir
config :planning_poker, :audio_transcription,
  whisper_model: "openai/whisper-base",        # Model name from HuggingFace
  max_audio_duration_seconds: 600,             # 10 minutes max
  max_file_size_mb: 50,                        # 50MB max file size
  model_idle_timeout_minutes: 30,              # Keep model in memory
  file_cleanup_delay_hours: 2                  # Delay before file deletion
```

**Requirements:**
- **Browser**: Chrome, Firefox, Safari, or Edge (any browser with MediaRecorder API)
- **Permissions**: Microphone access required
- **GitLab**: OAuth token must have `api` scope
- **Server**: Elixir/Erlang with EXLA support (CPU or GPU)
- **Memory**: ~500MB RAM for model (when loaded)
- **Disk**: ~290MB for cached model files

**First-Time Usage:**
On first voice comment, the system will:
1. Download Whisper base model (~290MB) from HuggingFace
2. This may take 1-5 minutes depending on connection speed
3. Model is cached permanently; subsequent uses are fast
4. Model loads into memory on first transcription request
5. Model stays in memory for 30 minutes, then auto-unloads

**Troubleshooting:**
- **"Microphone access denied"**: Grant permission in browser settings
- **"No microphone found"**: Connect a microphone and refresh
- **"Transcription failed"**: Check server logs for Whisper errors
- **"Failed to post comment"**: Verify GitLab token has `api` scope
- **Slow transcription**: First use downloads model; subsequent uses are faster
- **Model won't load**: Check `~/.cache/huggingface/` has write permissions

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
