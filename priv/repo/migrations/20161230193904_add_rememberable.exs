defmodule Registro.Repo.Migrations.AddRememberable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :remember_created_at, :datetime
    end

    create table(:rememberables) do
      add :series_hash, :string
      add :token_hash, :string
      add :token_created_at, :datetime
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps
    end

    create index(:rememberables, [:user_id])
    create index(:rememberables, [:series_hash])
    create index(:rememberables, [:token_hash])
    create unique_index(:rememberables, [:user_id, :series_hash, :token_hash])
  end
end
