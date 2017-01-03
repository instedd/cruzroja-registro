defmodule Registro.Repo.Migrations.AddAddressToBranches do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :address, :string
    end
  end
end
