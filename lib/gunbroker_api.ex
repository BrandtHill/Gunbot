defmodule Gunbot.GunbrokerApi do

  @category_id 851

  defp headers do
    [
      {"X-DevKey", Application.get_env(:gunbot, :dev_key)},
      {"Content-Type", "application/json"}
    ]
  end

  def get_items(keywords, max_price \\ nil) do
    params = [{"Categories", @category_id}, {"Keywords", keywords}]
    params = if max_price, do: params ++ [{"MaxPrice", max_price}]
    HTTPoison.get(Application.get_env(:gunbot, :api_url) <> "/Items", headers(), params: params)
  end

  def get_access_token do
    {:ok, credentials} = Jason.encode(%{
      username: Application.get_env(:gunbot, :username),
      password: Application.get_env(:gunbot, :password)})
    %{status_code: 200, body: body} = HTTPoison.post!(Application.get_env(:gunbot, :api_url) <> "/Users/AccessToken",  credentials, headers())
    token = body
    |> Jason.decode!()
    |> Map.get("accessToken")
    Application.put_env(:gunbot, :token, token)
  end
end
