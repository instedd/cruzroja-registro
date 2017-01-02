defmodule Registro.Branch do
  use Registro.Web, :model

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
end
