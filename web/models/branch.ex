defmodule Registro.Branch do
  use Registro.Web, :model
  alias Registro.Pagination

  @derive {Poison.Encoder, only: [:name, :id]}

  schema "branches" do
    field :name, :string
    field :address, :string
    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :address])
    |> validate_required([:name, :address])
    |> unique_constraint(:name)
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end

  def count do
    Registro.Repo.one(from b in Registro.Branch, select: count(b.id))
  end
end
