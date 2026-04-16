defmodule PlanningPoker.TokenCredentialsTest do
  use ExUnit.Case, async: false

  alias PlanningPoker.TokenCredentials

  # Fake clock used to simulate time advancing without sleeping.
  defmodule FakeClock do
    def set(seconds), do: :persistent_term.put({__MODULE__, :now}, seconds)
    def system_time(:second), do: :persistent_term.get({__MODULE__, :now})
    def system_time(_), do: :persistent_term.get({__MODULE__, :now})
  end

  setup do
    previous = Application.get_env(:planning_poker, :clock, System)
    Application.put_env(:planning_poker, :clock, FakeClock)
    FakeClock.set(1_000_000)

    on_exit(fn ->
      Application.put_env(:planning_poker, :clock, previous)
    end)

    :ok
  end

  describe "expired?/1" do
    test "returns false for tokens without expires_at" do
      refute TokenCredentials.expired?(%TokenCredentials{access_token: "mock"})
    end

    test "returns true when the current time has passed expires_at" do
      FakeClock.set(2_000)
      token = %TokenCredentials{access_token: "t", expires_at: 1_000}
      assert TokenCredentials.expired?(token)
    end

    test "returns false when the current time is before expires_at" do
      FakeClock.set(500)
      token = %TokenCredentials{access_token: "t", expires_at: 1_000}
      refute TokenCredentials.expired?(token)
    end
  end

  describe "expires_soon?/2" do
    test "returns false when expires_at is far in the future" do
      FakeClock.set(0)
      token = %TokenCredentials{access_token: "t", expires_at: 10_000}
      refute TokenCredentials.expires_soon?(token)
    end

    test "returns true within the default 5 minute buffer" do
      FakeClock.set(9_800)
      token = %TokenCredentials{access_token: "t", expires_at: 10_000}
      # 200s remaining < 300s buffer
      assert TokenCredentials.expires_soon?(token)
    end

    test "honours a custom buffer" do
      FakeClock.set(9_000)
      token = %TokenCredentials{access_token: "t", expires_at: 10_000}
      refute TokenCredentials.expires_soon?(token, 60)
      assert TokenCredentials.expires_soon?(token, 2_000)
    end

    test "tokens without expires_at never expire soon" do
      token = %TokenCredentials{access_token: "t"}
      refute TokenCredentials.expires_soon?(token)
    end
  end

  describe "refreshable?/1" do
    test "true when refresh_token is present" do
      assert TokenCredentials.refreshable?(%TokenCredentials{
               access_token: "a",
               refresh_token: "r"
             })
    end

    test "false when refresh_token is nil" do
      refute TokenCredentials.refreshable?(%TokenCredentials{access_token: "a"})
    end
  end

  describe "seconds_until_expiry/1" do
    test "returns nil for non-expiring tokens" do
      assert TokenCredentials.seconds_until_expiry(%TokenCredentials{access_token: "a"}) == nil
    end

    test "returns positive remaining seconds" do
      FakeClock.set(100)
      token = %TokenCredentials{access_token: "t", expires_at: 400}
      assert TokenCredentials.seconds_until_expiry(token) == 300
    end

    test "returns negative when already expired" do
      FakeClock.set(500)
      token = %TokenCredentials{access_token: "t", expires_at: 400}
      assert TokenCredentials.seconds_until_expiry(token) == -100
    end
  end

  describe "from_string/1" do
    test "wraps a token string as non-expiring credentials" do
      creds = TokenCredentials.from_string("some-token")
      assert creds.access_token == "some-token"
      assert creds.refresh_token == nil
      assert creds.expires_at == nil
      refute TokenCredentials.expired?(creds)
    end
  end
end
