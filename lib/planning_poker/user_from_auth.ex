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
    %{id: auth.uid, name: name, avatar: generate_initials_avatar(name)}
  end

  # Generate an initials-based avatar URL using ui-avatars.com
  # This service creates avatars with initials that work cross-domain
  defp generate_initials_avatar(name) do
    encoded_name = URI.encode_www_form(name)
    "https://ui-avatars.com/api/?name=#{encoded_name}&background=0D8ABC&color=fff&size=128"
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
