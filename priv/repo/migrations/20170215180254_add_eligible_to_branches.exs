defmodule Registro.Repo.Migrations.AddEligibleToBranches do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :eligible, :boolean, default: true, null: false
    end
  end
end
