defmodule Registro.Branch do
  use Registro.Web, :model

  @derive {Poison.Encoder, only: [:name, :id]}

  schema "branches" do
    field :name, :string
    field :address, :string

    many_to_many :admins, Registro.Datasheet,
      join_through: "branches_admins",
      on_replace: :delete # allow to delete admins by updating the branch

    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :address])
    |> validate_required([:name, :address])
    |> unique_constraint(:name)
  end

  def update_admins(changeset, admin_datasheets) do
    Ecto.Changeset.put_assoc(changeset, :admins, admin_datasheets)
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end

  def count do
    Registro.Repo.one(from b in Registro.Branch, select: count(b.id))
  end
end
