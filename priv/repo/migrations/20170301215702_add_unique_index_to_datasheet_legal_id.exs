defmodule Registro.Repo.Migrations.AddUniqueIndexToDatasheetLegalId do
  use Ecto.Migration

  def change do
    create unique_index(:datasheets, [:legal_id_kind, :legal_id_number], name: :index_datasheets_on_legal_id)
  end
end
