defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a profile image using Gravatar.

  Generates a Gravatar URL based on the user's email with initials as fallback.

  ## Examples

      <.profile_image user={user} class="w-8 h-8" />
      <.profile_image user={user} alt="User avatar" />
  """
  attr :user, :map, required: true
  attr :class, :string, default: ""
  attr :alt, :string, default: nil
  attr :rest, :global

  def profile_image(assigns) do
    assigns = assign(assigns, :src, generate_gravatar_url(assigns.user))
    assigns = assign(assigns, :alt, assigns.alt || Map.get(assigns.user, :name, ""))

    ~H"""
    <img
      src={@src}
      alt={@alt}
      class={@class}
      {@rest}
    />
    """
  end

  @doc """
  Renders a banner showing the remaining OAuth session time and a manual
  "extend session" button. Hidden for non-expiring tokens (mock provider).

  The `token_info` map must contain:
    * `:seconds_until_expiry` — integer (nullable)
    * `:refreshable` — boolean
    * `:refreshing` — boolean
    * `:non_expiring` — boolean
  """
  attr :token_info, :map, required: true

  def session_token_banner(assigns) do
    ~H"""
    <div :if={not @token_info.non_expiring} class="w-full flex justify-center">
      <div
        id="session-token-banner"
        class={[
          "flex items-center gap-3 px-4 py-2 m-2 rounded-lg shadow-sm text-sm",
          session_banner_class(@token_info)
        ]}
        role="status"
      >
        <span class="font-medium">
          <%= cond do %>
            <% @token_info.seconds_until_expiry == nil -> %>
              Sitzung aktiv
            <% @token_info.seconds_until_expiry <= 0 -> %>
              Sitzung abgelaufen
            <% true -> %>
              Sitzung läuft noch
              <span data-session-remaining-seconds={@token_info.seconds_until_expiry}>
                {format_remaining(@token_info.seconds_until_expiry)}
              </span>
          <% end %>
        </span>
        <span :if={@token_info.refreshing} class="loading loading-spinner loading-xs"></span>
        <button
          :if={@token_info.refreshable and not @token_info.refreshing}
          type="button"
          phx-click="refresh_token_now"
          class="btn btn-xs btn-primary"
          id="refresh-token-btn"
        >
          Jetzt verlängern
        </button>
        <a
          :if={not @token_info.refreshable}
          href="/auth/logout"
          class="btn btn-xs btn-warning"
        >
          Neu einloggen
        </a>
      </div>
    </div>
    """
  end

  # < 10 min  -> warning colour, otherwise neutral
  defp session_banner_class(%{seconds_until_expiry: nil}), do: "bg-base-200"

  defp session_banner_class(%{seconds_until_expiry: s}) when s <= 0,
    do: "bg-error text-error-content"

  defp session_banner_class(%{seconds_until_expiry: s}) when s < 600,
    do: "bg-warning text-warning-content"

  defp session_banner_class(_), do: "bg-base-200"

  defp format_remaining(seconds) when seconds <= 0, do: "0 min"

  defp format_remaining(seconds) do
    minutes = div(seconds, 60)

    cond do
      minutes < 1 -> "<1 min"
      minutes < 60 -> "#{minutes} min"
      true -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
    end
  end

  @doc """
  Renders a one-line byline for an issue, e.g. "Created on 15 Jan 2024 by Alice Anderson".

  Falls back to just the author or just the timestamp when only one of them is
  known, and renders nothing at all when the issue carries neither.
  """
  attr :issue, :map, required: true

  attr :class, :string,
    default: "mt-2 flex flex-wrap items-center gap-2 text-sm text-base-content/70"

  attr :comments_anchor, :string,
    default: nil,
    doc: "id of the comments block on the page; the count links there when given"

  def issue_byline(assigns) do
    assigns =
      assigns
      |> assign(:text, byline_text(assigns.issue))
      |> assign(:comment_label, comment_count_label(assigns.issue))
      |> assign(:priority, assigns.issue["priority"])

    ~H"""
    <p :if={@text || @comment_label || @priority} class={@class}>
      <span :if={@text}>{@text}</span>
      <span :if={@text && @comment_label} aria-hidden="true">·</span>
      <a
        :if={@comment_label && @comments_anchor}
        href={"##{@comments_anchor}"}
        phx-click={JS.set_attribute({"open", "true"}, to: "##{@comments_anchor}")}
        class="underline decoration-dotted underline-offset-2 hover:decoration-solid"
      >
        {@comment_label}
      </a>
      <span :if={@comment_label && !@comments_anchor}>{@comment_label}</span>
      <.issue_priority_badge issue={@issue} />
    </p>
    """
  end

  @doc """
  Renders the issue priority as an inline badge, and nothing at all when the
  issue has none.

  The provider supplies the human-readable option label (e.g. "High - Must Have").
  """
  attr :issue, :map, required: true
  attr :class, :string, default: nil

  def issue_priority_badge(assigns) do
    assigns = assign(assigns, :priority, assigns.issue["priority"])

    ~H"""
    <span :if={@priority} class={["badge badge-sm", priority_badge_class(@priority), @class]}>
      <span class="sr-only">Priority:</span>
      {@priority}
    </span>
    """
  end

  # The provider supplies the option label verbatim: "Urgent - ASAP",
  # "High - Next Sprint", "Medium - Next Version" or "Low - Nice to Have".
  # Matching on the leading word keeps this working if the wording after the
  # dash changes. The four levels escalate from muted to red; anything
  # unrecognised stays neutral rather than guessing at a severity.
  defp priority_badge_class("Urgent" <> _), do: "badge-error"
  defp priority_badge_class("High" <> _), do: "badge-warning"
  defp priority_badge_class("Medium" <> _), do: "badge-info"
  defp priority_badge_class("Low" <> _), do: "badge-ghost"
  defp priority_badge_class(_), do: "badge-neutral"

  @doc """
  Describes how many comments an issue has, or `nil` when it has none.

  ## Examples

      iex> PlanningPokerWeb.PlanningComponents.comment_count_label(%{"comments" => [%{}]})
      "1 comment"

      iex> PlanningPokerWeb.PlanningComponents.comment_count_label(%{"commentCount" => 3})
      "3 comments"

      iex> PlanningPokerWeb.PlanningComponents.comment_count_label(%{"comments" => [%{}, %{}]})
      "2 comments"

      iex> PlanningPokerWeb.PlanningComponents.comment_count_label(%{})
      nil
  """
  def comment_count_label(issue) do
    case comment_count(issue) do
      0 -> nil
      1 -> "1 comment"
      count -> "#{count} comments"
    end
  end

  # The list view is served a bare count, the detail view the comments
  # themselves; either answers the question.
  defp comment_count(issue) do
    issue["commentCount"] || length(List.wrap(issue["comments"]))
  end

  @doc """
  Builds the byline text for an issue, or `nil` when there is nothing to show.

  ## Examples

      iex> issue = %{"createdAt" => "2024-01-15T10:00:00Z", "author" => %{"name" => "Alice"}}
      iex> PlanningPokerWeb.PlanningComponents.byline_text(issue)
      "Created on 15 Jan 2024 by Alice"

      iex> PlanningPokerWeb.PlanningComponents.byline_text(%{"author" => %{"name" => "Bob"}})
      "Created by Bob"

      iex> PlanningPokerWeb.PlanningComponents.byline_text(%{})
      nil
  """
  def byline_text(issue) do
    author = author_name(issue)
    created = format_timestamp(issue["createdAt"])

    case {created, author} do
      {nil, nil} -> nil
      {nil, author} -> "Created by #{author}"
      {created, nil} -> "Created on #{created}"
      {created, author} -> "Created on #{created} by #{author}"
    end
  end

  @doc """
  Returns the name of an issue's author, or `nil` when it is unknown.

  ## Examples

      iex> PlanningPokerWeb.PlanningComponents.author_name(%{"author" => %{"name" => "Alice"}})
      "Alice"

      iex> PlanningPokerWeb.PlanningComponents.author_name(%{})
      nil
  """
  def author_name(issue), do: get_in(issue, ["author", "name"])

  @doc """
  Formats a timestamp as a date such as `"15 Jan 2024"`.

  Accepts an ISO 8601 string or a `DateTime`, and returns `nil` for a missing or
  unparseable timestamp. Offsets are normalised to UTC.

  ## Examples

      iex> PlanningPokerWeb.PlanningComponents.format_timestamp("2024-01-15T10:00:00Z")
      "15 Jan 2024"

      iex> PlanningPokerWeb.PlanningComponents.format_timestamp("not a timestamp")
      nil
  """
  def format_timestamp(nil), do: nil

  def format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> format_timestamp(datetime)
      {:error, _reason} -> nil
    end
  end

  def format_timestamp(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y")

  @doc """
  Formats a timestamp as a date and time such as `"15 Sep 2026, 11:44"`.

  Used where several entries can share a day and the time tells them apart.
  Accepts the same inputs as `format_timestamp/1` and returns `nil` the same way.

  ## Examples

      iex> PlanningPokerWeb.PlanningComponents.format_datetime("2026-09-15T11:44:09Z")
      "15 Sep 2026, 11:44"

      iex> PlanningPokerWeb.PlanningComponents.format_datetime(nil)
      nil
  """
  def format_datetime(nil), do: nil

  def format_datetime(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> format_datetime(datetime)
      {:error, _reason} -> nil
    end
  end

  def format_datetime(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%d %b %Y, %H:%M")

  # Generate a Gravatar URL using SHA256 hash of email
  # Falls back to initials-based generation if no Gravatar is found
  defp generate_gravatar_url(user) do
    email =
      Map.get(user, :email) || Map.get(user, "email") || "#{user.id || user["id"]}@example.com"

    name = Map.get(user, :name) || Map.get(user, "name") || "User"

    # SHA256 hash the email
    email_hash =
      email
      |> String.downcase()
      |> String.trim()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    # Extract initials for fallback: "Christoph Geschwind" -> "C G"
    initials =
      name
      |> String.split(" ")
      |> Enum.map(&String.first/1)
      |> Enum.join(" ")

    # URL encode the name parameter
    encoded_name = URI.encode_www_form(initials)

    "https://gravatar.com/avatar/#{email_hash}?d=initials&name=#{encoded_name}"
  end
end
