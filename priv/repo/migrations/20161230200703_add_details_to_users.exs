defmodule Registro.Repo.Migrations.AddDetailsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string
      add :status, :string
      add :branch, :integer
    end
  end
end
