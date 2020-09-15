defmodule Gunbot.Commands do

  alias Nostrum.Api
  alias Gunbot.TrackedSearch

  @prefix "!"

  @num_sec_day 60 * 60 * 24

  @commands %{
    "help"    => {&__MODULE__.help/1,   "Show all commands", "help"},
    "search"  => {&__MODULE__.search/1, "Do a one-time search", "search {PRICE} {KEYWORDS}"},
    "daily"   => {&__MODULE__.daily/1,  "Create a daily recurring search", "daily {PRICE} {KEYWORDS}"},
    "show"    => {&__MODULE__.show/1,   "Show all recurring searches", "show"},
    "remove"  => {&__MODULE__.remove/1, "Remove a recurring search", "remove {DAILY_SEARCH_ID}"}
  }

  def command_prefix, do: @prefix

  def dispatch(cmd, msg) do
    {function, _, _} = @commands
    |> Map.get(cmd)
    function.(msg)
  end

  def help(msg) do
    content = @commands
    |> Enum.reduce("", fn {cmd, {_, desc, usage}}, acc -> acc <> "#{@prefix}#{cmd} - #{desc} - #{@prefix}#{usage}\n" end)
    Api.create_message(msg.channel_id, content)
  end

  def search(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<price>\d+)\s+(?<keywords>.+$)/i, msg.content)
    message = unless matches do
      improperly_formatted("search")
    else
      case do_search(matches["keywords"], matches["price"]) do
        {:ok, m} -> m
        {:empty, m} -> "#{m} Consider creating a daily search to be notified if something is found."
        {:error, m} -> "#{m} Try re-running this command."
      end
    end
    Api.create_message(msg.channel_id, message)
  end

  def daily(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<price>\d+)\s+(?<keywords>.+$)/i, msg.content)
    message = unless matches do
      improperly_formatted("daily")
    else
      {:ok, tracked_search} = TrackedSearch.changeset(%TrackedSearch{}, %{
        max_price: matches["price"],
        keywords: matches["keywords"],
        user_id: msg.author.id,
        user_nickname: msg.member.nick || msg.author.username,
        last_checked: DateTime.utc_now |> DateTime.truncate(:second)
      }) |> Gunbot.Repo.insert
      case do_search(tracked_search) do
        {:ok, m} -> m
        {:empty, m} -> "#{m} You will be notified when if something is found."
        {:error, m} -> "#{m} Your daily search will still occur."
      end
    end
    Api.create_message(msg.channel_id, message)
  end

  def show(msg) do
    message =
    case Gunbot.Repo.all(TrackedSearch) do
      [] -> "No active recurring searches were found."
      all -> Enum.reduce(all, "", fn ts, acc -> acc <> "ID #{ts.id}: #{ts.user_nickname} is searching for #{ts.keywords} for $#{ts.max_price}\n" end)
    end
    Api.create_message(msg.channel_id, message)
  end

  def remove(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<id>\d+)\s*$/i, msg.content)
    message = unless matches do
      improperly_formatted("remove")
    else
      case Integer.parse(matches["id"]) do
        :error ->
          improperly_formatted("remove")
        {id, ""} ->
          if search = Gunbot.Repo.get(TrackedSearch, id) do
            if msg.author.id == search.user_id do
              case Gunbot.Repo.delete(search) do
                {:ok, _} -> "Search with id #{id} successfully removed."
                {:error, _} -> "An error occurred whilst trying to remove search with id #{id}."
              end
            else
              "Unable to remove #{search.user_nickname}'s search. You may only remove your own."
            end
          else
            "Unable to find a tracked search with id #{id}. Use `show` command to view searches."
          end
      end
    end
    Api.create_message(msg.channel_id, message)
  end

  defp improperly_formatted(cmd), do: "Improperly formatted. Usage: #{@prefix}#{@commands |> Map.get(String.downcase(cmd)) |> elem(2)}"

  defp mention(%TrackedSearch{} = tracked_search), do: mention(tracked_search.user_id)

  defp mention(user_id), do: "<@!#{user_id}> "

  def do_search(%TrackedSearch{} = tracked_search), do: do_search(tracked_search.keywords, tracked_search.max_price)

  def do_search(keywords, price) do
    case Gunbot.GunbrokerApi.get_items(keywords, price) do
      {:ok, %{status_code: 200, body: body}} ->
        json = Jason.decode! body
        if json["count"] < 1 do
          {:empty, "No items found."}
        else
          data = List.first json["results"]
          price = data["price"] |> :erlang.float_to_binary(decimals: 2)
          bid_price = data["bidPrice"] |> :erlang.float_to_binary(decimals: 2)
          item_id = data["itemID"] |> Integer.to_string
          gui_url = Application.get_env(:gunbot, :gui_url) <> "item/#{item_id}"
          {:ok, "I found *this* for $#{price} (current bid $#{bid_price}): #{gui_url}"}
        end
      _ ->
        {:error, "Error occurred whilst hitting Gunbroker API."}
    end
  end

  def do_scheduled_search(%TrackedSearch{} = tracked_search) do
    case DateTime.compare(DateTime.utc_now, tracked_search.last_checked |> DateTime.add(@num_sec_day)) do
      :gt ->
        TrackedSearch.changeset(tracked_search, %{last_checked: DateTime.utc_now |> DateTime.truncate(:second)})
        |> Gunbot.Repo.update!
        case do_search(tracked_search) do
          {:ok, search_message} -> mention(tracked_search) <> search_message
          _ -> nil
        end
      _ ->
        nil
    end
  end
end
