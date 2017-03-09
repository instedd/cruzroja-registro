defmodule Registro.Repo.Migrations.AddPayingFlagToDatasheets do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      add :is_paying_associate, :boolean
    end
  end
end
