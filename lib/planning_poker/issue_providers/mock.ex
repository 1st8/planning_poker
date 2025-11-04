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

  The adapter provides 6 sample issues with varying complexity:
  - Simple bug fixes
  - Feature requests
  - Complex technical debt items
  - Issues with and without epic associations

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
        avatar: "https://ui-avatars.com/api/?name=Alice+Anderson&background=0D8ABC&color=fff"
      },
      "bob" => %{
        id: "mock-user-bob",
        name: "Bob Builder",
        avatar: "https://ui-avatars.com/api/?name=Bob+Builder&background=F59E0B&color=fff"
      },
      "carol" => %{
        id: "mock-user-carol",
        name: "Carol Chen",
        avatar: "https://ui-avatars.com/api/?name=Carol+Chen&background=8B5CF6&color=fff"
      }
    }
  end

  defp initial_issues do
    [
      %{
        "id" => "mock-issue-1",
        "iid" => "1",
        "title" => "Add user profile page",
        "description" => """
        # User Profile Page

        Users should be able to view and edit their profile information.

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
        "descriptionHtml" => "<h1>User Profile Page</h1><p>Users should be able to view and edit their profile information.</p>",
        "referencePath" => "planning-poker#1",
        "webUrl" => "http://localhost:4000/mock/issues/1",
        "author" => %{"name" => "Alice Anderson"},
        "createdAt" => "2024-01-15T10:00:00Z",
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
      }
    ]
    |> Enum.map(fn issue -> {issue["id"], issue} end)
    |> Map.new()
  end
end
