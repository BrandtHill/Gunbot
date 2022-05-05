defmodule Gunbot.GunbrokerApi do
  @categories %{
    "Guns" => 851,
    "Pistols" => 978,
    "Rifles" => 979,
    "Shotguns" => 980,
    "Ammo" => 1012,
    "Optics" => 1017
  }

  defp headers do
    [
      {"X-DevKey", Application.get_env(:gunbot, :dev_key)},
      {"Content-Type", "application/json"}
    ]
  end

  def get_items(keywords, max_price \\ nil, category \\ "Guns") do
    params = [{"Categories", @categories[category]}, {"Keywords", keywords}, {"PageSize", "3"}]
    params = if max_price, do: params ++ [{"MaxPrice", max_price}], else: []
    HTTPoison.get(Application.get_env(:gunbot, :api_url) <> "/Items", headers(), params: params)
  end

  def get_ffls(zip) do
    params = [{"PageSize", "3"}]

    HTTPoison.get(Application.get_env(:gunbot, :api_url) <> "/FFLs/Zip/#{zip}", headers(),
      params: params
    )
  end

  def get_ffl(id) do
    HTTPoison.get(Application.get_env(:gunbot, :api_url) <> "/FFLs/#{id}", headers())
  end

  def get_access_token do
    {:ok, credentials} =
      Jason.encode(%{
        username: Application.get_env(:gunbot, :username),
        password: Application.get_env(:gunbot, :password)
      })

    %{status_code: 200, body: body} =
      HTTPoison.post!(
        Application.get_env(:gunbot, :api_url) <> "/Users/AccessToken",
        credentials,
        headers()
      )

    body
    |> Jason.decode!()
    |> Map.get("accessToken")
  end
end
