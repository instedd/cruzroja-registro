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
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :address, :phone_number, :cell_phone_number, :email, :president, :authorities])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end

  def count do
    Registro.Repo.one(from b in Registro.Branch, select: count(b.id))
  end
end
