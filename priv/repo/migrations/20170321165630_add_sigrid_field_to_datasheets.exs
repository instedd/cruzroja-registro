defmodule Registro.Repo.Migrations.AddSigridFieldToDatasheets do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      add :sigrid_profile_id, :integer
      add :extranet_profile_id, :integer
    end
  end
end
