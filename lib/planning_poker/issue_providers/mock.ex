defmodule PlanningPoker.IssueProviders.Mock do
  @moduledoc """
  Mock issue provider for local development and testing.

  This adapter provides:
  - Three mock users (Alice, Bob, Carol) for testing collaboration features
  - Sample issues with realistic content
  - In-memory state (resets on application restart)
  - Simple authentication via username

  ## Authentication

  To "authenticate" as a mock user, use the username parameter:

      client = Mock.client(user_id: "alice")

  Available users: "alice", "bob", "carol"

  ## Mock Data

  The adapter provides 8 sample issues with varying complexity:
  - Simple bug fixes
  - Feature requests
  - Complex technical debt items
  - Issues with and without epic associations
  - Issues with collapsible `<details>` sections for testing

  All data resets when the application restarts.
  """

  use GenServer
  require Logger
  @behaviour PlanningPoker.IssueProvider

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl PlanningPoker.IssueProvider
  def client(opts \\ []) do
    user_id =
      cond do
        user_id = Keyword.get(opts, :user_id) -> user_id
        token = Keyword.get(opts, :token) -> extract_user_from_token(token)
        true -> "alice"
      end

    %{provider: :mock, user_id: user_id}
  end

  defp extract_user_from_token("mock-token-" <> username), do: username
  defp extract_user_from_token(_), do: "alice"

  @impl PlanningPoker.IssueProvider
  def fetch_issues(_client, _opts \\ []) do
    issues = GenServer.call(__MODULE__, :get_issues)
    {:ok, issues}
  end

  @impl PlanningPoker.IssueProvider
  def fetch_issue(_client, issue_id, _opts \\ []) do
    issue = GenServer.call(__MODULE__, {:get_issue, issue_id})

    case issue do
      nil -> {:error, :not_found}
      issue -> {:ok, issue}
    end
  end

  @impl PlanningPoker.IssueProvider
  def update_issue(_client, _project_id, issue_iid, attrs) do
    result = GenServer.call(__MODULE__, {:update_issue, issue_iid, attrs})

    case result do
      nil -> {:error, :not_found}
      issue -> {:ok, issue}
    end
  end

  @doc """
  Gets a mock user by username.

  Returns a user map with id, name, and avatar fields suitable for session storage.
  """
  def get_user(username) when username in ["alice", "bob", "carol"] do
    users = mock_users()
    Map.get(users, username)
  end

  def get_user(_), do: nil

  @doc """
  Returns all available mock users.
  """
  def list_users do
    mock_users()
    |> Map.values()
    |> Enum.sort_by(& &1.id)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    state = %{
      issues: initial_issues(),
      users: mock_users()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_issues, _from, state) do
    # Return all issues as a list
    issues = Map.values(state.issues)
    {:reply, issues, state}
  end

  @impl true
  def handle_call({:get_issue, issue_id}, _from, state) do
    issue = Map.get(state.issues, issue_id)

    # Add base_url like GitLab adapter does
    enhanced_issue =
      if issue do
        Map.put(issue, :base_url, "http://localhost:4000")
      end

    {:reply, enhanced_issue, state}
  end

  @impl true
  def handle_call({:update_issue, issue_iid, attrs}, _from, state) do
    # Find issue by iid
    issue =
      state.issues
      |> Map.values()
      |> Enum.find(&(&1["iid"] == issue_iid))

    case issue do
      nil ->
        {:reply, nil, state}

      found_issue ->
        # Update the issue with new attributes (string keys)
        string_attrs = for {key, val} <- attrs, into: %{}, do: {to_string(key), val}

        # Log what's being updated
        changes =
          string_attrs
          |> Enum.map(fn {key, new_val} ->
            old_val = Map.get(found_issue, key)

            case key do
              "weight" ->
                "weight: #{inspect(old_val)} → #{inspect(new_val)}"

              "description" ->
                old_preview = if old_val, do: String.slice(old_val, 0..50), else: "nil"
                new_preview = if new_val, do: String.slice(new_val, 0..50), else: "nil"
                "description: #{old_preview}... → #{new_preview}..."

              _ ->
                "#{key}: #{inspect(old_val)} → #{inspect(new_val)}"
            end
          end)
          |> Enum.join(", ")

        Logger.info("""
        Mock provider: Updating issue ##{issue_iid}
        Title: #{found_issue["title"]}
        Changes: #{changes}
        """)

        updated_issue =
          found_issue
          |> Map.merge(string_attrs)
          |> Map.put(:base_url, "http://localhost:4000")

        # Update state
        new_state = put_in(state.issues[found_issue["id"]], updated_issue)

        {:reply, updated_issue, new_state}
    end
  end

  # Private Functions

  defp mock_users do
    %{
      "alice" => %{
        id: "mock-user-alice",
        name: "Alice Anderson",
        email: "alice@example.com",
        avatar: nil
      },
      "bob" => %{
        id: "mock-user-bob",
        name: "Bob Builder",
        email: "bob@example.com",
        avatar: nil
      },
      "carol" => %{
        id: "mock-user-carol",
        name: "Carol Chen",
        email: "carol@example.com",
        avatar: nil
      }
    }
  end

  defp initial_issues do
    [
      %{
        "id" => "mock-issue-1",
        "iid" => "1",
        "projectId" => "25",
        "title" => "Add user profile page",
        "description" => """
        # User Profile Page

        Users should be able to view and edit their profile information.

        ![Profile mockup](/uploads/467af08891cb18bb726bcc3b1d4c098e/225434.jpg)

        ## Requirements
        - Display user name, email, avatar
        - Allow editing of name and avatar
        - Show user's recent activity
        - Add settings for notifications

        ## Acceptance Criteria
        - [ ] Profile page loads correctly
        - [ ] User can update their name
        - [ ] Avatar upload works
        - [ ] Recent activity list displays
        """,
        "descriptionHtml" =>
          "<h1>User Profile Page</h1><p>Users should be able to view and edit their profile information.</p>",
        "referencePath" => "planning-poker#1",
        "webUrl" => "http://localhost:4000/mock/issues/1",
        "author" => %{"name" => "Alice Anderson"},
        "createdAt" => "2024-01-15T10:00:00Z",
        "priority" => "High - Next Sprint",
        "comments" => [
          %{
            "id" => "mock-note-1",
            "body" => """
            Ich habe mir das mal angesehen. Der Avatar-Upload braucht noch eine
            Entscheidung: **Gravatar** oder eigener Upload?

            - Gravatar: nichts zu speichern, aber externe Abhängigkeit
            - Upload: mehr Arbeit, dafür unabhängig
            """,
            "author" => %{"name" => "Bob Builder"},
            "createdAt" => "2024-01-15T13:20:00Z"
          },
          %{
            "id" => "mock-note-2",
            "body" =>
              "Lass uns mit Gravatar starten, der Upload kann später kommen. Siehe auch #3.",
            "author" => %{"name" => "Carol Chen"},
            "createdAt" => "2024-01-16T08:05:00Z"
          }
        ],
        "weight" => nil,
        "epic" => %{
          "title" => "User Management Epic",
          "reference" => "&1"
        }
      },
      %{
        "id" => "mock-issue-2",
        "iid" => "2",
        "title" => "Fix login page styling on mobile",
        "description" => """
        The login page doesn't render correctly on mobile devices. The form extends beyond the viewport and the submit button is cut off.

        ## Steps to Reproduce
        1. Open login page on mobile device or narrow viewport
        2. Observe layout issues

        ## Expected Behavior
        Form should be responsive and fit within viewport on all screen sizes.
        """,
        "descriptionHtml" => "<p>The login page doesn't render correctly on mobile devices.</p>",
        "referencePath" => "planning-poker#2",
        "webUrl" => "http://localhost:4000/mock/issues/2",
        "author" => %{"name" => "Bob Builder"},
        "createdAt" => "2024-01-16T14:30:00Z",
        "priority" => "Low - Nice to Have",
        "comments" => [
          %{
            "id" => "mock-note-3",
            "body" => "Tritt nur auf Geräten unter 400px Breite auf.",
            "author" => %{"name" => "Alice Anderson"},
            "createdAt" => "2024-01-17T09:00:00Z"
          }
        ],
        "weight" => nil
      },
      %{
        "id" => "mock-issue-3",
        "iid" => "3",
        "title" => "Implement real-time notifications",
        "description" => """
        # Real-time Notifications

        Add a notification system that alerts users when:
        - Someone votes in their planning session
        - A planning session reaches consensus
        - They're mentioned in a comment

        ## Technical Approach
        Use Phoenix Channels for real-time delivery. Consider browser notifications API for desktop alerts.

        ## Design Notes
        - Bell icon in header with badge count
        - Dropdown panel showing recent notifications
        - Mark as read functionality
        """,
        "descriptionHtml" => "<h1>Real-time Notifications</h1>",
        "referencePath" => "planning-poker#3",
        "webUrl" => "http://localhost:4000/mock/issues/3",
        "author" => %{"name" => "Carol Chen"},
        "createdAt" => "2024-01-17T09:15:00Z",
        "priority" => "Medium - Next Version",
        "weight" => nil,
        "epic" => %{
          "title" => "Communication Features",
          "reference" => "&2"
        }
      },
      %{
        "id" => "mock-issue-4",
        "iid" => "4",
        "title" => "Refactor database queries for performance",
        "description" => """
        # Database Performance Optimization

        Several queries are running slowly in production:

        ## Problem Areas
        1. Session list query loads all participants eagerly
        2. Issue fetching doesn't use indexes properly
        3. N+1 queries when loading vote results

        ## Proposed Solutions
        - Add database indexes on foreign keys
        - Use `preload` instead of separate queries
        - Implement query result caching
        - Consider denormalizing vote counts

        ## Metrics
        Current avg response time: 450ms
        Target: <100ms
        """,
        "descriptionHtml" => "<h1>Database Performance Optimization</h1>",
        "referencePath" => "planning-poker#4",
        "webUrl" => "http://localhost:4000/mock/issues/4",
        "author" => %{"name" => "Alice Anderson"},
        "createdAt" => "2024-01-18T11:00:00Z",
        "priority" => "Urgent - ASAP",
        "weight" => nil,
        "epic" => %{
          "title" => "Technical Debt",
          "reference" => "&3"
        }
      },
      %{
        "id" => "mock-issue-5",
        "iid" => "5",
        "title" => "Add keyboard shortcuts",
        "description" => """
        Add keyboard shortcuts for common actions:

        - `v` - Start voting
        - `r` - Reveal votes
        - `n` - Next issue
        - `1-5` - Quick vote with Fibonacci numbers
        - `?` - Show help overlay with all shortcuts

        Should work during voting phase and be discoverable.
        """,
        "descriptionHtml" => "<p>Add keyboard shortcuts for common actions</p>",
        "referencePath" => "planning-poker#5",
        "webUrl" => "http://localhost:4000/mock/issues/5",
        "author" => %{"name" => "Bob Builder"},
        "createdAt" => "2024-01-19T15:45:00Z",
        "weight" => nil
      },
      %{
        "id" => "mock-issue-6",
        "iid" => "6",
        "title" => "Export planning session results",
        "description" => """
        # Export Session Results

        Users should be able to export planning session results in multiple formats:

        ## Export Formats
        - CSV (for spreadsheets)
        - JSON (for API integrations)
        - Markdown (for documentation)

        ## Data to Include
        - Issue title and reference
        - Final estimate
        - All participant votes
        - Timestamp
        - Session ID

        ## UI
        Add "Export" button to session results view with format selector dropdown.
        """,
        "descriptionHtml" => "<h1>Export Session Results</h1>",
        "referencePath" => "planning-poker#6",
        "webUrl" => "http://localhost:4000/mock/issues/6",
        "author" => %{"name" => "Carol Chen"},
        "createdAt" => "2024-01-20T08:30:00Z",
        "weight" => nil,
        "epic" => %{
          "title" => "Data Integration",
          "reference" => "&4"
        }
      },
      %{
        "id" => "mock-issue-8",
        "iid" => "8",
        "projectId" => "25",
        "title" => "Image rendering bug in collapsible sections",
        "description" => """
        # Image in Details Block Test

        This issue is used to test rendering of images inside collapsible `<details>` sections.

        <details>
        <summary>Screenshot</summary>

        ![Beiträge_und_Interessantes](/static/Generated Image December 04, 2025 - 12_43PM.png)

        </details>

        ## Expected Behavior

        - Images should load correctly when details sections are expanded
        - Layout should not break when toggling details open/closed
        - Presence updates should not collapse open details sections
        """,
        "descriptionHtml" => "<h1>Image in Details Block Test</h1>",
        "referencePath" => "planning-poker#8",
        "webUrl" => "http://localhost:4000/mock/issues/8",
        "author" => %{"name" => "Carol Chen"},
        "createdAt" => "2024-01-22T14:00:00Z",
        "weight" => nil
      },
      %{
        "id" => "mock-issue-7",
        "iid" => "7",
        "projectId" => "25",
        "title" => "Implement advanced search with filters",
        "description" => """
        # Advanced Search Feature

        Add a comprehensive search feature that allows users to find issues quickly using filters and advanced query syntax.

        ## Overview

        Users need to search through large issue backlogs efficiently. The current simple search is not sufficient for teams with hundreds of issues.

        <details>
        <summary>Technical Implementation Details</summary>

        ### Backend Architecture

        The search will use a multi-stage approach:

        1. **Query Parsing**: Parse user input into search terms and filters
        2. **Database Query**: Build dynamic Ecto queries based on filters
        3. **Ranking**: Sort results by relevance score
        4. **Caching**: Cache frequent searches for 5 minutes

        ### Database Indexes Required

        ```sql
        CREATE INDEX idx_issues_title_trgm ON issues USING gin(title gin_trgm_ops);
        CREATE INDEX idx_issues_description_trgm ON issues USING gin(description gin_trgm_ops);
        CREATE INDEX idx_issues_status ON issues(status);
        CREATE INDEX idx_issues_assignee ON issues(assignee_id);
        ```

        ### Performance Considerations

        - Limit results to 100 items
        - Use EXPLAIN ANALYZE for query optimization
        - Consider ElasticSearch for large datasets (>10k issues)
        </details>

        <details>
        <summary>UI/UX Design Mockups</summary>

        ### Search Bar Design

        The search bar should be prominently placed in the header with autocomplete:

        - Dropdown suggestions as user types
        - Recent searches history
        - Syntax hints for filters

        ### Filter Panel

        Left sidebar with collapsible sections:

        - **Status**: Open, In Progress, Closed
        - **Assignee**: User selector with avatars
        - **Labels**: Tag cloud with counts
        - **Date Range**: Created/Updated date pickers
        - **Weight**: Story point range slider

        ### Results Display

        Cards showing:
        - Issue title (highlighted matches)
        - Snippet of description with search terms highlighted
        - Metadata badges (status, assignee, labels)
        - Quick actions (view, edit, estimate)
        </details>

        <details>
        <summary>Search Query Syntax Examples</summary>

        Users can combine text search with filters:

        ```
        # Text search
        authentication bug

        # With status filter
        authentication bug status:open

        # Multiple filters
        authentication assignee:alice label:security created:>2024-01-01

        # Exact phrase matching
        "user authentication" status:open

        # Exclude terms
        authentication -oauth

        # OR operator
        authentication OR authorization
        ```

        ### Filter Operators

        - `:` - Equals (status:open)
        - `:>` - Greater than (weight:>5)
        - `:<` - Less than (created:<2024-01-01)
        - `:*` - Contains (title:*search*)
        </details>

        ## Acceptance Criteria

        - [ ] Search bar is accessible from all pages
        - [ ] Autocomplete shows relevant suggestions
        - [ ] Filters can be combined and work correctly
        - [ ] Results highlight matching terms
        - [ ] Search completes in <200ms for typical queries
        - [ ] Mobile-responsive design
        - [ ] Keyboard navigation support (arrow keys, enter to select)

        ## Testing Strategy

        - Unit tests for query parser
        - Integration tests for database queries
        - E2E tests for UI interactions
        - Performance benchmarks with large datasets
        """,
        "descriptionHtml" => "<h1>Advanced Search Feature</h1>",
        "referencePath" => "planning-poker#7",
        "webUrl" => "http://localhost:4000/mock/issues/7",
        "author" => %{"name" => "Alice Anderson"},
        "createdAt" => "2024-01-21T10:00:00Z",
        "weight" => nil,
        "epic" => %{
          "title" => "Search & Discovery",
          "reference" => "&5"
        }
      },
      %{
        "id" => "mock-issue-9",
        "iid" => "9",
        "title" => "Migrate the reporting pipeline to the new analytics backend",
        "description" => """
        # Reporting Pipeline Migration

        The current reporting pipeline was built around the legacy analytics
        service and has grown well past what it was designed for. Nightly runs
        regularly overshoot their window, backfills have to be babysat, and every
        new report means touching three different services. This issue tracks
        moving the whole pipeline onto the new analytics backend.

        This is a deliberately long issue: it exists to exercise the scrolling
        behaviour of the issue view.

        ## Background

        The pipeline currently consists of four stages that each evolved
        separately over the last three years:

        1. **Collection** — a cron job pulls raw events from the primary database
           and writes them to object storage as newline-delimited JSON.
        2. **Normalisation** — a second job reads those files, applies a pile of
           accumulated correction rules, and writes Parquet.
        3. **Aggregation** — a set of SQL scripts build the daily rollups that
           back every dashboard.
        4. **Delivery** — a mailer renders the rollups into the weekly digest.

        Each stage has its own retry semantics, its own alerting, and its own idea
        of what a "day" is. Stage 1 uses UTC, stage 3 uses the reporting tenant's
        local timezone, and stage 4 uses whatever the recipient's profile says.
        This is the source of most of the discrepancies people report.

        ## Goals

        - Collapse the four stages into a single orchestrated workflow
        - One consistent definition of a reporting day, applied end to end
        - Backfills that can be triggered without manual intervention
        - Cut the nightly run from roughly six hours to under one
        - No change to the numbers users already see, except where they were wrong

        ## Non-Goals

        - Redesigning the dashboards themselves
        - Changing the weekly digest layout
        - Migrating historical data older than 24 months
        - Replacing the primary database

        ## Proposed Architecture

        The new backend gives us incremental materialised views, which removes the
        need for the hand-written aggregation scripts entirely.

        ```
        events ──▶ ingest ──▶ staging tables ──▶ materialised views ──▶ API
                     │                                    │
                     └── dead letter queue                └── digest renderer
        ```

        Ingest becomes the only component we own outright. Everything downstream
        is declarative, which means the correction rules have to move somewhere
        explicit rather than living inside the normalisation job.

        ### Ingest

        A single long-running consumer replaces the collection cron. It reads from
        the event stream, validates against a schema, and writes into staging
        tables. Anything that fails validation goes to a dead letter queue with
        enough context to replay it.

        ```elixir
        defmodule Reporting.Ingest do
          def handle_batch(events) do
            events
            |> Enum.map(&validate/1)
            |> Enum.split_with(&match?({:ok, _}, &1))
            |> then(fn {ok, failed} ->
              write_staging(ok)
              write_dead_letter(failed)
            end)
          end
        end
        ```

        ### Correction Rules

        The normalisation job currently carries 47 correction rules, most of them
        undocumented and several of them contradictory. Before the migration each
        rule needs to be classified:

        | Category | Count | Action |
        | --- | --- | --- |
        | Schema fixes | 18 | Move into the ingest schema |
        | Historical one-offs | 14 | Freeze as a static backfill, then drop |
        | Tenant-specific | 9 | Move into tenant configuration |
        | Unknown | 6 | Investigate individually |

        The six unknown rules are the risk here. Three of them reference tenant
        IDs that no longer exist. The other three appear to correct for a bug that
        was fixed upstream two years ago, but nobody is certain.

        <details>
        <summary>Full list of the six unknown rules</summary>

        - `rule_0012` — rewrites `event_type` from `signup` to `registration` for
          tenant 4471, which was deleted in 2023
        - `rule_0019` — drops events where `duration_ms` is negative; upstream has
          not emitted negative durations since the clock fix
        - `rule_0023` — same as `rule_0019` but scoped to a single region
        - `rule_0031` — adds a synthetic `source` field when missing; the field has
          been required at ingest since last spring
        - `rule_0038` — references tenant 5120, also deleted
        - `rule_0044` — references tenant 5121, also deleted

        Recommendation: drop all six behind a flag, run a week of shadow
        comparison, and remove them if nothing changes.

        </details>

        ## Migration Plan

        The migration runs in five phases. Phases 1 and 2 are safe to run against
        production because nothing reads from the new backend yet.

        ### Phase 1 — Shadow Ingest

        Stand up the ingest consumer alongside the existing collection job. Both
        write, nothing reads. Run for two weeks and compare row counts daily.

        - [ ] Deploy the consumer to staging
        - [ ] Verify schema validation against a full day of production events
        - [ ] Deploy to production with writes disabled
        - [ ] Enable writes to the staging tables
        - [ ] Set up the daily comparison report
        - [ ] Review two weeks of comparisons

        ### Phase 2 — Materialised Views

        Build the views that replace the aggregation scripts. Each view gets
        validated against the corresponding legacy rollup before anything switches
        over.

        - [ ] Port the daily active users rollup
        - [ ] Port the retention cohort rollup
        - [ ] Port the revenue rollup
        - [ ] Port the per-tenant usage rollup
        - [ ] Reconcile each against 90 days of legacy output
        - [ ] Document every discrepancy found

        ### Phase 3 — Read Switch

        Point the API at the new views, one dashboard at a time, behind a
        per-tenant flag. Start with internal tenants.

        - [ ] Flag infrastructure in the API
        - [ ] Switch internal tenants
        - [ ] Switch 5% of external tenants
        - [ ] Switch 50%
        - [ ] Switch everyone

        ### Phase 4 — Digest

        Move the weekly digest onto the new API. This is the phase most likely to
        produce user-visible differences, because the digest is where the timezone
        inconsistency is most obvious.

        - [ ] Render both versions for a full cycle
        - [ ] Diff the rendered output
        - [ ] Get sign-off on the differences that are corrections
        - [ ] Cut over

        ### Phase 5 — Decommission

        - [ ] Disable the collection cron
        - [ ] Disable the normalisation job
        - [ ] Archive the aggregation scripts
        - [ ] Remove the legacy tables after a 30 day hold
        - [ ] Update the runbooks

        ## Risks

        **Discrepancies that turn out to be corrections.** Some of the numbers
        people rely on are wrong today. Fixing them silently during a migration is
        how you lose trust in the whole pipeline. Every difference found in phase 2
        needs to be written down and explicitly signed off before phase 3.

        **The 24 month boundary.** Anything older stays in the legacy tables. The
        API needs to serve both, which means a union view for the overlap period
        and a clear story for what happens when someone asks for three year old
        data.

        **Backfill cost.** The initial backfill is an estimated 40 hours of compute.
        It has to run without blocking the incremental path, which the new backend
        supports but which we have not tested at this volume.

        **Nobody owns the digest renderer.** It was written by someone who has
        since left, has no tests, and is the only component that talks directly to
        the mailer.

        ## Acceptance Criteria

        - [ ] Nightly run completes in under one hour at p95
        - [ ] Backfills can be triggered from the admin UI
        - [ ] Every dashboard shows the same numbers pre- and post-migration,
              except where a discrepancy was explicitly signed off
        - [ ] A reporting day means the same thing in every stage
        - [ ] The dead letter queue is monitored and alerting
        - [ ] Legacy jobs are removed, not merely disabled
        - [ ] Runbooks updated for the new failure modes

        ## Open Questions

        1. Do we keep the union view permanently, or force a hard cutoff at 24
           months and accept that older data becomes unavailable?
        2. Should tenant-specific correction rules be configuration or code?
           Configuration is more flexible; code is reviewable.
        3. Who owns the digest renderer after this lands?
        4. Is 40 hours of backfill compute acceptable, or do we need to stage it?

        ## References

        - The original pipeline design document from 2021
        - The analytics backend evaluation from last quarter
        - The incident review from the March backfill failure
        - The timezone discrepancy thread in support
        """,
        "descriptionHtml" => "<h1>Reporting Pipeline Migration</h1>",
        "referencePath" => "planning-poker#9",
        "webUrl" => "http://localhost:4000/mock/issues/9",
        "author" => %{"name" => "Bob Builder"},
        "createdAt" => "2024-01-23T09:00:00Z",
        "priority" => "High - Next Sprint",
        "weight" => nil,
        "epic" => %{
          "title" => "Analytics Platform",
          "reference" => "&6"
        }
      }
    ]
    |> Enum.map(fn issue -> {issue["id"], issue} end)
    |> Map.new()
  end
end
