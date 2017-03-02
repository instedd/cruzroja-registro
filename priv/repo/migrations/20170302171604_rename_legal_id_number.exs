defmodule Registro.Repo.Migrations.RenameLegalIdNumber do
  use Ecto.Migration

  def change do
    rename table(:datasheets), :legal_id_number, to: :legal_id
  end
end
