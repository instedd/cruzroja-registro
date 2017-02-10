defmodule Registro.Repo.Migrations.AddBranchesClerks do
  use Ecto.Migration

  def change do
    create table(:branches_clerks) do
      add :branch_id, references(:branches)
      add :datasheet_id, references(:datasheets)
    end
  end
end
