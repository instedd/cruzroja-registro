defmodule Registro.Datasheet do
  use Registro.Web, :model

  alias Registro.Role

  schema "datasheets" do
    field :name, :string
    field :status, :string
    field :role, :string

    belongs_to :branch, Registro.Branch
    has_one :user, Registro.User
  end


  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :status, :branch_id, :role])
    |> validate_required([:name])
    |> validate_volunteer_fields
  end

  def pending_approval?(datasheet) do
    datasheet.status == "at_start"
  end

  def status_label(status) do
    case status do
      "at_start" -> "Pendiente"
      "approved" -> "Aprobado"
      "rejected" -> "Rechazado"
      _ -> ""
    end
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

  defp valid_status?(status) do
    Enum.member? ["at_start", "approved", "rejected"], status
  end
end
