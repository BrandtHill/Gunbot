defmodule Gunbot.Commands do
  alias Gunbot.{GunbrokerApi, Repo, TrackedSearch}

  import Ecto.Query, only: [from: 2]
  alias Ecto.Changeset

  opt = fn type, name, desc, opts ->
    %{type: type, name: name, description: desc}
    |> Map.merge(Enum.into(opts, %{}))
  end

  @categories ["Guns", "Pistols", "Rifles", "Shotguns", "Ammo", "Optics"]

  @search_category_choices Enum.map(@categories, &%{name: &1, value: &1})

  @search_opts_opts [
    opt.(3, "category", "Search category", required: true, choices: @search_category_choices),
    opt.(3, "keywords", "Search keywords", required: true),
    opt.(4, "price", "Maximum price to search for", required: true)
  ]

  @search_opts [
    opt.(1, "once", "Do a one-time search", options: @search_opts_opts),
    opt.(1, "daily", "Create a daily recurring search", options: @search_opts_opts)
  ]

  @ffl_opts [
    opt.(3, "zip", "ZIP code to search in", required: true)
  ]

  @remove_opts [
    opt.(4, "id", "ID to remove", required: true)
  ]

  @commands %{
    "help" => {:help, "Show all commands", []},
    "search" => {:search, "Do a search", @search_opts},
    "ffl" => {:ffl, "Search for nearby FFLs", @ffl_opts},
    "show" => {:show, "Show all recurring searches", []},
    "remove" => {:remove, "Remove a recurring search", @remove_opts}
  }

  def commands, do: @commands

  def dispatch(%{data: %{name: cmd}} = interaction) do
    case Map.get(@commands, cmd) do
      {function, _, _} -> :erlang.apply(__MODULE__, function, [interaction])
      nil -> nil
    end
  end

  def help(_interaction) do
    Enum.map_join(@commands, "\n", fn {cmd, {_, desc, _}} -> "/#{cmd} - #{desc}" end)
  end

  def search(%{guild_id: g_id, channel_id: c_id, member: member, data: %{options: options}}) do
    [%{name: name, options: [%{value: category}, %{value: keywords}, %{value: price}]}] = options

    changeset =
      TrackedSearch.build(%{
        max_price: price,
        keywords: keywords,
        category: category,
        user_id: member.user.id,
        guild_id: g_id,
        channel_id: c_id,
        user_nickname: member.nick || member.user.username,
        last_checked: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    if changeset.valid? do
      ts =
        if(name == "daily",
          do: Repo.insert!(changeset),
          else: Changeset.apply_changes(changeset)
        )

      do_search(ts) |> elem(1)
    else
      "Invalid parameters given"
    end
  end

  def ffl(%{data: %{options: [%{value: zip}]}} = _interaction) do
    case do_ffl_by_zip(zip) do
      {:ok, msg} -> msg
      {:empty, msg} -> "#{msg} Try another zip code."
      {:error, msg} -> "#{msg} Try re-running this command."
    end
  end

  def show(%{guild_id: guild_id} = _interaction) do
    case Repo.all(from(t in TrackedSearch, where: t.guild_id == ^guild_id)) do
      [] ->
        "No active recurring searches were found in this guild."

      all ->
        Enum.map_join(all, "\n", fn %TrackedSearch{} = t ->
          "#{t.id}: #{t.user_nickname} searching for #{t.category}, #{t.keywords}, $#{t.max_price}"
        end)
    end
  end

  def remove(%{user: %{id: user_id}, data: %{options: [%{value: id}]}} = _interaction) do
    case Repo.get(TrackedSearch, id) do
      nil ->
        "Unable to find a tracked search with id #{id}. Use `show` command to view searches."

      %TrackedSearch{user_id: t_uid} = ts when t_uid == user_id ->
        case Repo.delete(ts) do
          {:ok, _} -> "Search with id #{id} successfully removed."
          {:error, _} -> "An error occurred whilst trying to remove search with id #{id}."
        end

      %TrackedSearch{} = ts ->
        "Unable to remove #{ts.user_nickname}'s search. You may only remove your own."
    end
  end

  defp mention(%TrackedSearch{user_id: user_id}), do: mention(user_id)
  defp mention(user_id), do: "<@!#{user_id}> "

  def do_search(%TrackedSearch{keywords: kw, max_price: price, category: cat}),
    do: do_search(kw, price, cat)

  def do_search(keywords, price, category) do
    case GunbrokerApi.get_items(keywords, price, category) do
      {:ok, %{status_code: 200, body: body}} ->
        json = Jason.decode!(body)

        if json["count"] < 1 do
          {:empty, "No items found."}
        else
          msg =
            json["results"]
            |> Enum.take(3)
            |> Enum.map_join("\n", fn data ->
              price = data["price"] |> :erlang.float_to_binary(decimals: 2)
              bid_price = data["bidPrice"] |> :erlang.float_to_binary(decimals: 2)
              item_id = data["itemID"] |> Integer.to_string()
              gui_url = Application.get_env(:gunbot, :gui_url) <> "item/#{item_id}"
              "I found *this* for $#{price} (current bid $#{bid_price}): #{gui_url}"
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
            |> Enum.reduce("I found some nearby FFLs\n", fn data, acc ->
              acc <> do_ffl_details(data["fflID"]) <> "\n"
            end)

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

        "**#{company}**   #{address} #{city}" <>
          "#{if(hours != "", do: "\n\tHours: " <> hours)}" <>
          "#{if(phone != "", do: "\n\tPhone: " <> phone)}" <>
          "\n\tLong Gun Fee: #{lg_fee}" <>
          "\n\tHand Gun Fee: #{hg_fee}" <>
          "#{if(nics_fee > 0, do: "\n\tNICs Check Fee: $#{nics_fee}")}"

      _ ->
        nil
    end
  end
end
