defmodule Registro.User do
  use Registro.Web, :model
  use Coherence.Schema

  schema "users" do
    field :name, :string
    field :email, :string
    field :status, :string
    field :role, :string
    belongs_to :branch, Registro.Branch
    coherence_schema

    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :email, :status, :branch_id, :role] ++ coherence_fields)
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_coherence(params)
  end

  def can_read(user) do
    user.role == "administrator" or user.role == "branch_employee"
  end
end
