defmodule Gunbot.Repo.Migrations.AddCategory do
  use Ecto.Migration

  def change do
    alter table(:tracked_searches) do
      add :category, :string, default: "Guns"
    end
  end
end
