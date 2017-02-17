defmodule Registro.Repo.Migrations.AddObservationsToDatasheet do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      add :observations, :text
    end
  end
end
