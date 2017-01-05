defmodule Registro.User do
  use Registro.Web, :model
  use Coherence.Schema

  alias Registro.Role

  schema "users" do
    field :name, :string
    field :email, :string
    field :status, :string
    field :role, :string
    belongs_to :branch, Registro.Branch
    coherence_schema

    timestamps
  end

  def changeset(:new_volunteer, model, params) do
    params = params |> Dict.merge(%{"status" => "at_start"})
    changeset(model, params)
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :email, :status, :branch_id, :role] ++ coherence_fields)
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_coherence(params)
    |> validate_volunteer_fields
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

  def valid_status?(status) do
    Enum.member? ["at_start", "approved", "rejected"], status
  end

  def pending_approval?(user) do
    user.status == "at_start"
  end

  defp validate_volunteer_fields(changeset) do
    role = Ecto.Changeset.get_field(changeset, :role)

    if !Role.is_admin?(role) do
      changeset
      |> validate_required([:branch_id, :status])
      |> validate_status
    else
      changeset
    end
  end

  defp validate_status(changeset) do
    status = Ecto.Changeset.get_field(changeset, :status)
    if !valid_status?(status) do
      changeset |> Ecto.Changeset.add_error(:status, "is invalid")
    else
      changeset
    end
  end
end
