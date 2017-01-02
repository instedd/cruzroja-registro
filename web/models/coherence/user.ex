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

  def role_label(role) do
    case role do
      "administrator" -> "Empleado de Sede Central"
      "branch_employee" -> "Empleado de Filial"
      "volunteer" -> "Voluntario"
    end
  end

  def is_employee?(user) do
    user.role == "administrator" or user.role == "branch_employee"
  end

  def pending_approval?(user) do
    # TODO: check status
    !is_employee?(user)
  end

  def can_read(user) do
    user.role == "administrator" or user.role == "branch_employee"
  end
end
