defmodule Registro.Repo.Migrations.AddFieldsToBranch do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :president, :string
      add :authorities , :string
      add :phone_number, :string
      add :cell_phone_number, :string
      add :email, :string
    end
  end
end
