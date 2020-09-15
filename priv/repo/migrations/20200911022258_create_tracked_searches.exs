defmodule Gunbot.Repo.Migrations.CreateTrackedSearches do
  use Ecto.Migration

  def change do
    create table(:tracked_searches) do
      add :user_id, :bigint
      add :user_nickname, :string
      add :max_price, :integer
      add :keywords, :string
      add :last_checked, :utc_datetime
    end
  end
end
