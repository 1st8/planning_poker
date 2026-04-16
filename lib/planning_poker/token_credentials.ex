defmodule PlanningPoker.TokenCredentials do
  @moduledoc """
  Holds OAuth credentials for GitLab API access.

  Wraps access_token, refresh_token, and expires_at into a single struct
  that replaces the bare token string throughout the application.
  """

  @enforce_keys [:access_token]
  defstruct [:access_token, :refresh_token, :expires_at]

  @type t :: %__MODULE__{
          access_token: String.t(),
          refresh_token: String.t() | nil,
          expires_at: integer() | nil
        }

  @doc """
  Returns true if the token has expired.
  Tokens without `expires_at` are considered non-expiring (e.g. mock tokens).
  """
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) do
    PlanningPoker.Clock.system_time(:second) >= expires_at
  end

  @doc """
  Returns true if the token will expire within `buffer_seconds` (default 5 minutes).
  """
  def expires_soon?(credentials, buffer_seconds \\ 300)
  def expires_soon?(%__MODULE__{expires_at: nil}, _buffer_seconds), do: false

  def expires_soon?(%__MODULE__{expires_at: expires_at}, buffer_seconds) do
    PlanningPoker.Clock.system_time(:second) >= expires_at - buffer_seconds
  end

  @doc """
  Returns the remaining time in seconds until the token expires.
  Returns `nil` for non-expiring tokens (e.g. mock). May be negative if already expired.
  """
  def seconds_until_expiry(%__MODULE__{expires_at: nil}), do: nil

  def seconds_until_expiry(%__MODULE__{expires_at: expires_at}) do
    expires_at - PlanningPoker.Clock.system_time(:second)
  end

  @doc """
  Returns true if the token has a refresh_token that can be used for renewal.
  """
  def refreshable?(%__MODULE__{refresh_token: nil}), do: false
  def refreshable?(%__MODULE__{refresh_token: _}), do: true

  @doc """
  Wraps a plain token string into a TokenCredentials struct.
  Used for mock tokens and backward compatibility.
  """
  def from_string(token) when is_binary(token) do
    %__MODULE__{access_token: token}
  end
end
