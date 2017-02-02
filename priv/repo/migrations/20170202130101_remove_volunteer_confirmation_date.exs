defmodule Registro.Repo.Migrations.RemoveVolunteerConfirmationDate do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      remove :volunteer_since
    end
  end
end
