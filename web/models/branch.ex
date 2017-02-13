defmodule Registro.Branch do
  use Registro.Web, :model

  @derive {Poison.Encoder, only: [:name, :id]}

  schema "branches" do
    field :name, :string
    field :address, :string
    field :phone_number, :string
    field :cell_phone_number, :string
    field :email, :string
    field :president, :string
    field :authorities, :string
    timestamps

    many_to_many :admins, Registro.Datasheet,
      join_through: "branches_admins",
      on_replace: :delete # allow to delete admins by updating the branch

    many_to_many :clerks, Registro.Datasheet,
      join_through: "branches_clerks",
      on_replace: :delete # allow to delete admins by updating the branch
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :address, :phone_number, :cell_phone_number, :email, :president, :authorities])
    |> validate_required([:name])
    |> unique_constraint(:name, message: "ya pertenece a otra filial")
  end

  def update_admins(changeset, admin_datasheets) do
    Ecto.Changeset.put_assoc(changeset, :admins, admin_datasheets)
  end

  def update_clerks(changeset, clerk_datasheets) do
    Ecto.Changeset.put_assoc(changeset, :clerks, clerk_datasheets)
  end

  def admin_changes(changeset) do
    previous_admins = changeset.data.admins |> Enum.map(&(&1.id))
    updated_admins  = changeset |> Ecto.Changeset.get_field(:admins) |> Enum.map(&(&1.id))

    added_admins = updated_admins
    |> Enum.reject(fn id -> Enum.member?(previous_admins, id) end)

    removed_admins = previous_admins
    |> Enum.reject(fn id -> Enum.member?(updated_admins, id) end)

    {added_admins, removed_admins}
  end

  def clerk_changes(changeset) do
    previous_clerks = changeset.data.clerks |> Enum.map(&(&1.id))
    updated_clerks  = changeset |> Ecto.Changeset.get_field(:clerks) |> Enum.map(&(&1.id))

    added_clerks = updated_clerks
                 |> Enum.reject(fn id -> Enum.member?(previous_clerks, id) end)

    removed_clerks = previous_clerks
                   |> Enum.reject(fn id -> Enum.member?(updated_clerks, id) end)

    {added_clerks, removed_clerks}
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end

  def count do
    Registro.Repo.one(from b in Registro.Branch, select: count(b.id))
  end

  def accessible_by(datasheet) do
    if datasheet.is_super_admin do
      all
    else
      datasheet.admin_branches ++ datasheet.clerk_branches
    end
  end
end
