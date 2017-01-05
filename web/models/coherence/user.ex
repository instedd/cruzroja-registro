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
    Registro.Role.label(role)
  end

  def status_label(status) do
    case status do
      "at_start" -> "Pendiente"
      "approved" -> "Aprobado"
      "rejected" -> "Rechazado"
      _ -> ""
    end
  end

  def pending_approval?(user) do
    user.status == "at_start"
  end
end
