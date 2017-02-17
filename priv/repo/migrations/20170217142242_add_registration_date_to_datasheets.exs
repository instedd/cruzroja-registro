defmodule Registro.Repo.Migrations.AddRegistrationDateToDatasheets do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      add :registration_date, :date
    end
  end
end
