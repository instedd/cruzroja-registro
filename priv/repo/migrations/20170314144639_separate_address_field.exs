defmodule Registro.Repo.Migrations.SeparateAddressField do
  use Ecto.Migration

  def change do
    alter table(:datasheets) do
      remove :address
      add :address_street, :string
      add :address_number, :integer
      add :address_block, :string
      add :address_floor, :integer
      add :address_apartement, :string
      add :address_city, :string
      add :address_province, :string
      add :postal_code, :integer
    end
  end
end
