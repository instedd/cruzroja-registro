defmodule Registro.Repo.Migrations.AddPhoneNumberToDatasheets do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      add :phone_number, :string
    end
  end
end
