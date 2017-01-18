defmodule Registro.Repo.Migrations.AddFieldsToDatasheets do
  use Ecto.Migration

  @doc """
  This migration declares fields that cant' be NULL, and there is no sane value
  to set for pre-existing data. Also, we shouldn't add default values for these
  columns: that would mean any value could be invalid.

  Since at the moment there is no real-world deployment of the application, it
  makes sense for this migration not to work on non-empty databases, force any
  development/test database to be cleared and make sure we always work with a
  valid schema.
  """
  def change do
    create table(:countries) do
      add :name, :string, null: false
    end

    flush

    execute "ALTER TABLE datasheets ALTER COLUMN name SET NOT NULL"
    execute "ALTER TABLE datasheets RENAME COLUMN name TO first_name"

    alter table(:datasheets) do
      add :last_name, :string, null: false
      add :legal_id, :integer, null: false
      add :country_id, references(:countries), null: false
      add :birth_date, :date, null: false
      add :occupation, :string, null: false
      add :address, :string, null: false
    end
  end
end
