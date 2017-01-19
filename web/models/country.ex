defmodule Registro.Country do
  use Registro.Web, :model

  schema "countries" do
    field :name, :string
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def all do
    Registro.Repo.all(__MODULE__)
  end
end
