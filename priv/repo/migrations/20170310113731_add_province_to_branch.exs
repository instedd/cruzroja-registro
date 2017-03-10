defmodule Registro.Repo.Migrations.AddProvinceToBranch do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :province, :string
    end
  end
end
