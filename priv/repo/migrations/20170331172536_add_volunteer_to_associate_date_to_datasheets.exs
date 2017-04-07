defmodule Registro.Repo.Migrations.AddVolunteerToAssociateDateToDatasheets do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      add :volunteer_to_associate_date, :date
      add :staff_observations, :text
    end

    create table(:volunteer_activity) do
      add :datasheet_id, references(:datasheets)
      add :description, :string
      add :date, :date
      timestamps()
    end

    create table(:associate_payments) do
      add :datasheet_id, references(:datasheets)
      add :date, :date
      timestamps()
    end
  end
end
