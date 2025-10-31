defmodule PlanningPoker.IssueProvider do
  @moduledoc """
  Behavior for issue provider adapters (GitLab, GitHub, Jira, Mock, etc.).

  This allows the Planning Poker application to work with different issue
  tracking systems by implementing a common interface for authentication,
  issue fetching, and issue management.

  ## Configuration

  The active provider is configured via the `ISSUE_PROVIDER` environment variable:

      export ISSUE_PROVIDER=mock    # Use mock adapter for local dev
      export ISSUE_PROVIDER=gitlab  # Use GitLab adapter (default in production)

  If not set, defaults to:
  - `mock` in `:dev` and `:test` environments
  - `gitlab` in `:prod` environment

  ## Implementing a Provider

  A provider module must implement the following callbacks:

  1. `client/1` - Create an authenticated client
  2. `fetch_issues/2` - Fetch a list of issues for planning
  3. `fetch_issue/3` - Fetch detailed information for a specific issue

  See the individual callback documentation for details on expected inputs and outputs.
  """

  @doc """
  Creates an authenticated client for the provider.

  ## Options

  - `:token` - Authentication token (for OAuth-based providers)
  - `:user_id` - User identifier (for mock/test providers)
  - Other provider-specific options

  ## Returns

  An opaque client structure that will be passed to `fetch_issues/2` and `fetch_issue/3`.
  """
  @callback client(opts :: keyword()) :: any()

  @doc """
  Fetches a list of issues to be estimated.

  ## Arguments

  - `client` - The authenticated client from `client/1`
  - `opts` - Provider-specific options (e.g., list_id, board_id, filters)

  ## Returns

  - `{:ok, issues}` where `issues` is a list of issue maps
  - `{:error, reason}` on failure

  ## Expected Issue Format

  Each issue map should contain:

  - `"id"` (string, required) - Globally unique issue identifier
  - `"title"` (string, required) - Issue title/summary
  - `"referencePath"` (string, required) - Human-readable reference (e.g., "project#123")
  - `"webUrl"` (string, required) - URL to view the issue in the provider's UI
  """
  @callback fetch_issues(client :: any(), opts :: keyword()) ::
              {:ok, [map()]} | {:error, any()}

  @doc """
  Fetches detailed information for a specific issue.

  ## Arguments

  - `client` - The authenticated client from `client/1`
  - `issue_id` - The issue ID from the `"id"` field returned by `fetch_issues/2`
  - `opts` - Provider-specific options

  ## Returns

  - `{:ok, issue}` where `issue` is a detailed issue map
  - `{:error, reason}` on failure

  ## Expected Issue Format

  The issue map should contain all fields from the list format, plus:

  - `"description"` (string) - Raw markdown/plain text description
  - `"descriptionHtml"` (string) - HTML-formatted description
  - `"author"` (map) - Author information with `"name"` field
  - `"createdAt"` (string) - ISO 8601 timestamp
  - `"epic"` (map, optional) - Epic/parent information with `"title"` and `"reference"` fields
  - `:base_url` (string, atom key) - Base URL of the provider instance
  - Other provider-specific fields

  The implementation may also add computed fields like `"sections"` for collaborative editing.
  """
  @callback fetch_issue(client :: any(), issue_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Updates an issue with new attributes.

  ## Arguments

  - `client` - The authenticated client from `client/1`
  - `project_id` - The project identifier (format varies by provider)
  - `issue_iid` - The issue internal ID (e.g., "123" for #123)
  - `attrs` - Map of attributes to update (e.g., `%{description: "updated content"}`)

  ## Returns

  - `{:ok, issue}` where `issue` is the updated issue map
  - `{:error, reason}` on failure

  ## Example

      iex> client = IssueProvider.client(token: "token")
      iex> IssueProvider.update_issue(client, "1st8/planning_poker", "42", %{description: "New description"})
      {:ok, %{"id" => "...", "description" => "New description", ...}}
  """
  @callback update_issue(
              client :: any(),
              project_id :: String.t(),
              issue_iid :: String.t(),
              attrs :: map()
            ) :: {:ok, map()} | {:error, any()}

  @doc """
  Returns the configured issue provider module.

  Checks the `ISSUE_PROVIDER` environment variable, falling back to defaults
  based on `Mix.env()`:

  - `:dev` and `:test` default to `PlanningPoker.IssueProviders.Mock`
  - `:prod` defaults to `PlanningPoker.IssueProviders.Gitlab`

  ## Examples

      iex> PlanningPoker.IssueProvider.get_provider()
      PlanningPoker.IssueProviders.Mock
  """
  def get_provider do
    case System.get_env("ISSUE_PROVIDER") do
      "mock" -> PlanningPoker.IssueProviders.Mock
      "gitlab" -> PlanningPoker.IssueProviders.Gitlab
      nil -> default_provider()
      other -> raise "Unknown ISSUE_PROVIDER: #{other}. Must be 'mock' or 'gitlab'."
    end
  end

  defp default_provider do
    case Mix.env() do
      env when env in [:dev, :test] -> PlanningPoker.IssueProviders.Mock
      :prod -> PlanningPoker.IssueProviders.Gitlab
    end
  end

  @doc """
  Creates a client using the configured provider.

  This is a convenience function that delegates to `get_provider().client(opts)`.
  """
  def client(opts \\ []) do
    get_provider().client(opts)
  end

  @doc """
  Fetches issues using the configured provider.

  This is a convenience function that delegates to `get_provider().fetch_issues(client, opts)`.
  """
  def fetch_issues(client, opts \\ []) do
    get_provider().fetch_issues(client, opts)
  end

  @doc """
  Fetches a specific issue using the configured provider.

  This is a convenience function that delegates to `get_provider().fetch_issue(client, issue_id, opts)`.
  """
  def fetch_issue(client, issue_id, opts \\ []) do
    get_provider().fetch_issue(client, issue_id, opts)
  end

  @doc """
  Updates an issue using the configured provider.

  This is a convenience function that delegates to `get_provider().update_issue(client, project_id, issue_iid, attrs)`.
  """
  def update_issue(client, project_id, issue_iid, attrs) do
    get_provider().update_issue(client, project_id, issue_iid, attrs)
  end
end
