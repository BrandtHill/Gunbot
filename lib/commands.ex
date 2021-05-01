defmodule Gunbot.Commands do
  alias Nostrum.Api
  alias Gunbot.{GunbrokerApi, Repo, TrackedSearch}

  import Ecto.Query, only: [from: 2]

  @prefix "!"

  @commands %{
    "help" =>   {&__MODULE__.help/1,    "Show all commands", "help"},
    "search" => {&__MODULE__.search/1,  "Do a one-time search", "search {PRICE} {KEYWORDS}"},
    "daily" =>  {&__MODULE__.daily/1,   "Create a daily recurring search", "daily {PRICE} {KEYWORDS}"},
    "ffl" =>    {&__MODULE__.ffl/1,     "Search for nearby FFLs", "ffl {ZIP_CODE}"},
    "show" =>   {&__MODULE__.show/1,    "Show all recurring searches", "show"},
    "remove" => {&__MODULE__.remove/1,  "Remove a recurring search", "remove {DAILY_SEARCH_ID}"}
  }

  def command_prefix, do: @prefix

  def dispatch(cmd, msg) do
    {function, _, _} =
      @commands
      |> Map.get(cmd)

    function.(msg)
  end

  def help(msg) do
    content =
      @commands
      |> Enum.reduce("", fn {cmd, {_, desc, usage}}, acc ->
        acc <> "#{@prefix}#{cmd} - #{desc} - #{@prefix}#{usage}\n"
      end)

    Api.create_message(msg.channel_id, content)
  end

  def search(msg) do
    matches =
      Regex.named_captures(
        ~r/^#{@prefix}\s*(?<command>\w+)\s+(?<price>\d+)\s+(?<keywords>.+$)/i,
        msg.content
      )

    message =
      if !matches do
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
    matches =
      Regex.named_captures(
        ~r/^#{@prefix}\s*(?<command>\w+)\s+(?<price>\d+)\s+(?<keywords>.+$)/i,
        msg.content
      )

    message =
      if !matches do
        improperly_formatted("daily")
      else
        {:ok, tracked_search} =
          TrackedSearch.changeset(%TrackedSearch{}, %{
            max_price: matches["price"],
            keywords: matches["keywords"],
            user_id: msg.author.id,
            guild_id: msg.guild_id,
            channel_id: msg.channel_id,
            user_nickname: msg.member.nick || msg.author.username,
            last_checked: DateTime.utc_now() |> DateTime.truncate(:second)
          })
          |> Repo.insert()

        case do_search(tracked_search) do
          {:ok, m} -> m
          {:empty, m} -> "#{m} You will be notified when something is found."
          {:error, m} -> "#{m} Your daily search will still occur."
        end
      end

    Api.create_message(msg.channel_id, message)
  end

  def ffl(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<zip>\d+)\s*$/i, msg.content)

    message =
      if !matches do
        improperly_formatted("ffl")
      else
        case do_ffl_by_zip(matches["zip"]) do
          {:ok, m} -> m
          {:empty, m} -> "#{m} Try another zip code."
          {:error, m} -> "#{m} Try re-running this command."
        end
      end

    Api.create_message(msg.channel_id, message)
  end



  def show(msg) do
    message =
      case Repo.all(from t in TrackedSearch, where: t.guild_id == ^msg.guild_id) do
        [] ->
          "No active recurring searches were found in this guild."

        all ->
          Enum.reduce(all, "", fn ts, acc ->
            acc <> "ID #{ts.id}: #{ts.user_nickname} is searching for #{ts.keywords} for $#{ts.max_price}\n"
          end)
      end

    Api.create_message(msg.channel_id, message)
  end

  def remove(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<id>\d+)\s*$/i, msg.content)

    message =
      if !matches do
        improperly_formatted("remove")
      else
        case Integer.parse(matches["id"]) do
          :error ->
            improperly_formatted("remove")

          {id, ""} ->
            if search = Repo.get(TrackedSearch, id) do
              if msg.author.id == search.user_id do
                case Repo.delete(search) do
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

  defp improperly_formatted(cmd),
    do: "Improperly formatted. Usage: #{@prefix}#{@commands |> Map.get(String.downcase(cmd)) |> elem(2)}"

  defp mention(%TrackedSearch{} = tracked_search), do: mention(tracked_search.user_id)

  defp mention(user_id), do: "<@!#{user_id}> "

  def do_search(%TrackedSearch{} = tracked_search),
    do: do_search(tracked_search.keywords, tracked_search.max_price)

  def do_search(keywords, price) do
    case GunbrokerApi.get_items(keywords, price) do
      {:ok, %{status_code: 200, body: body}} ->
        json = Jason.decode!(body)

        if json["count"] < 1 do
          {:empty, "No items found."}
        else
          msg =
            Enum.take(json["results"], 3)
            |> Enum.reduce("", fn data, acc ->
              price = data["price"] |> :erlang.float_to_binary(decimals: 2)
              bid_price = data["bidPrice"] |> :erlang.float_to_binary(decimals: 2)
              item_id = data["itemID"] |> Integer.to_string()
              gui_url = Application.get_env(:gunbot, :gui_url) <> "item/#{item_id}"
              acc <> "I found *this* for $#{price} (current bid $#{bid_price}): #{gui_url}\n"
            end)

          {:ok, msg}
        end

      _ ->
        {:error, "Error occurred whilst hitting Gunbroker API."}
    end
  end

  def do_scheduled_search(%TrackedSearch{} = tracked_search) do
    case do_search(tracked_search) do
      {:ok, search_message} ->
        mention(tracked_search) <> "\n" <> search_message

      _ ->
        nil
    end
  end

  def do_ffl_by_zip(zip) do
    case GunbrokerApi.get_ffls(zip) do
      {:ok, %{status_code: 200, body: body}} ->
        json = Jason.decode!(body)

        if json["count"] < 1 do
          {:empty, "No FFLs found."}
        else
          msg =
            Enum.take(json["results"], 3)
            |> Enum.reduce("I found some nearby FFLs\n", fn data, acc -> acc <> do_ffl_details(data["fflID"]) <> "\n" end)

          {:ok, msg}
        end

      _ ->
        {:error, "Error occurred whilst hitting Gunbroker API."}
    end
  end

  def do_ffl_details(id) do
    case GunbrokerApi.get_ffl(id) do
      {:ok, %{status_code: 200, body: body}} ->
        json = Jason.decode!(body)
        company = json["company"]
        address = "#{json["address1"]} #{json["address2"]}"
        city = "#{json["city"]}, #{json["state"]} #{json["zip"]}"
        lg_fee = "$#{json["longGunFee"]} #{json["longGunDescription"]}"
        hg_fee = "$#{json["handGunFee"]} #{json["handGunDescription"]}"
        nics_fee = json["nicsFee"]
        hours = "#{json["hours"]}"
        phone = "#{json["phone"]}"

        "**#{company}**   #{address} #{city}"
        <> "#{if(hours != "", do: "\n\tHours: " <> hours)}"
        <> "#{if(phone != "", do: "\n\tPhone: " <> phone)}"
        <> "\n\tLong Gun Fee: #{lg_fee}"
        <> "\n\tHand Gun Fee: #{hg_fee}"
        <> "#{if(nics_fee > 0, do: "\n\tNICs Check Fee: $#{nics_fee}")}"

      _ ->
        nil
    end
  end
end
