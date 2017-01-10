defmodule Registro.Repo.Migrations.AddDatasheetFkToInvitation do
  use Ecto.Migration

  def change do
    alter table(:invitations) do
      add :datasheet_id, references(:datasheets)
    end
  end
end
