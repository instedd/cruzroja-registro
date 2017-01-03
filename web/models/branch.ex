defmodule Registro.Branch do
  use Registro.Web, :model
  @derive {Poison.Encoder, only: [:name, :id]}

  schema "branches" do
    field :name, :string
    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end
end
