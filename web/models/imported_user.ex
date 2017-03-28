defmodule Registro.ImportedUser do
  use Registro.Web, :model

  alias __MODULE__
  alias Registro.User
  alias Registro.Branch
  alias Registro.Invitation

  schema "imported_users" do
    field :first_name, :string
    field :last_name, :string
    field :legal_id_kind, :string
    field :legal_id, :string
    field :birth_date, :date
    field :occupation, :string
    field :phone_number, :string
    field :registration_date, :date
    field :observations, :string
    field :address_street, :string
    field :address_number, :integer
    field :address_block, :string
    field :address_floor, :integer
    field :address_apartement, :string
    field :address_city, :string
    field :address_province, :string
    field :postal_code, :integer

    field :email, :string
    field :sigrid_profile_id, :integer
    field :extranet_profile_id, :integer

    field :role, :string
    field :is_paying_associate, :boolean
    field :branch_name
  end

  def as_params(user) do
    branch = case user.branch_name do
      nil -> nil
      name -> Registro.Repo.one from b in Branch, where: like(b.name, ^("%#{name}%"))
    end
    if branch do
      branch = branch.id
    end
    %{  first_name: user.first_name,
        last_name: user.last_name,
        legal_id_kind: user.legal_id_kind,
        legal_id: user.legal_id,
        birth_date: user.birth_date,
        occupation: user.occupation,
        phone_number: user.phone_number,
        registration_date: user.registration_date,
        observations: user.observations,
        address_street: user.address_street,
        address_number: user.address_number,
        address_block: user.address_block,
        address_floor: user.address_floor,
        address_apartement: user.address_apartement,
        address_city: user.address_city,
        address_province: user.address_province,
        postal_code: user.postal_code,
        role: user.role,
        is_paying_associate: user.is_paying_associate,
        branch_id: branch,
        sigrid_profile_id: user.sigrid_profile_id,
        extranet_profile_id: user.extranet_profile_id
    }
  end
end
