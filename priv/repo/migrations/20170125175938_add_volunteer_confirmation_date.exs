defmodule Registro.Repo.Migrations.AddVolunteerConfirmationDate do
  use Ecto.Migration

  def up do
    alter table(:datasheets) do
      add :volunteer_since, :date
    end

    flush

    Registro.Repo.query!("UPDATE datasheets SET volunteer_since = NOW() WHERE role = 'volunteer' AND status = 'approved'")
  end

  def down do
    alter table(:datasheets) do
      remove :volunteer_since
    end
  end
end
