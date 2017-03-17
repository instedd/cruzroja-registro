defmodule Registro.Repo.Migrations.CreateImportedUsers do
  use Ecto.Migration

  def change do
    create table(:imported_users) do
      add :first_name, :string
      add :last_name, :string
      add :legal_id_kind, :string
      add :legal_id, :string
      add :birth_date, :date
      add :occupation, :string
      add :phone_number, :string
      add :registration_date, :date
      add :observations, :string
      add :address_street, :string
      add :address_number, :integer
      add :address_block, :string
      add :address_floor, :integer
      add :address_apartement, :string
      add :address_city, :string
      add :address_province, :string
      add :postal_code, :integer
      add :email, :string
      add :role, :string
      add :is_paying_associate, :boolean
      add :branch_name, :string
      add :sigrid_profile_id, :integer
      add :extranet_profile_id, :integer
    end
  end
end
