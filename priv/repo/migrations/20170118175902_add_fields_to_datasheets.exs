defmodule Registro.Repo.Migrations.AddFieldsToDatasheets do
  use Ecto.Migration

  def up do
    create table(:countries) do
      add :name, :string
    end

    rename table(:datasheets), :name, to: :first_name

    alter table(:datasheets) do
      add :last_name, :string
      add :legal_id_kind, :string
      add :legal_id_number, :string
      add :country_id, references(:countries)
      add :birth_date, :date
      add :occupation, :string
      add :address, :string
      add :filled, :boolean, default: false
    end

    execute "UPDATE datasheets SET filled = TRUE where first_name != 'Completar'"
    execute "UPDATE datasheets SET first_name = NULL where first_name = 'Completar'"
  end

  def down do
    alter table(:datasheets) do
      remove :last_name
      remove :legal_id_kind
      remove :legal_id_number
      remove :country_id
      remove :birth_date
      remove :occupation
      remove :address
      remove :filled
    end

    rename table(:datasheets), :first_name, to: :name

    execute "UPDATE datasheets SET name = 'COMPLETAR' where name IS NULL"

    drop table(:countries)
  end
end
