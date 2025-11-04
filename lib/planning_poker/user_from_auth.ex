# Source: https://github.com/ueberauth/ueberauth_example/blob/master/lib/ueberauth_example/user_from_auth.ex

defmodule PlanningPoker.UserFromAuth do
  @moduledoc """
  Retrieve the user information from an auth request
  """
  require Logger
  require Jason

  alias Ueberauth.Auth

  def find_or_create(%Auth{} = auth) do
    {:ok, basic_info(auth)}
  end

  defp basic_info(auth) do
    name = name_from_auth(auth)
    email = auth.info.email || "#{auth.uid}@example.com"
    %{id: auth.uid, name: name, avatar: generate_gravatar_url(email, name)}
  end

  # Generate a Gravatar URL using SHA256 hash of email
  # Falls back to initials-based generation if no Gravatar is found
  defp generate_gravatar_url(email, name) do
    # SHA256 hash the email
    email_hash =
      email
      |> String.downcase()
      |> String.trim()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    # Extract initials for fallback: "Christoph Geschwind" -> "C+G"
    initials =
      name
      |> String.split(" ")
      |> Enum.map(&String.first/1)
      |> Enum.join("+")
      |> URI.encode_www_form()

    "https://gravatar.com/avatar/#{email_hash}?d=initials&name=#{initials}"
  end

  defp name_from_auth(auth) do
    if auth.info.name do
      auth.info.name
    else
      name =
        [auth.info.first_name, auth.info.last_name]
        |> Enum.filter(&(&1 != nil and &1 != ""))

      if Enum.empty?(name) do
        auth.info.nickname
      else
        Enum.join(name, " ")
      end
    end
  end
end
