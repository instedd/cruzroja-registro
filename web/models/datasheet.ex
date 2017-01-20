defmodule Registro.Datasheet do
  use Registro.Web, :model

  alias __MODULE__
  alias Registro.User
  alias Registro.Branch
  alias Registro.Invitation

  schema "datasheets" do
    field :first_name, :string
    field :last_name, :string
    field :legal_id_kind, :string
    field :legal_id_number, :string
    field :birth_date, :date
    field :occupation, :string
    field :address, :string

    field :status, :string
    field :role, :string
    field :is_super_admin, :boolean

    field :filled, :boolean

    has_one :user, Registro.User
    has_one :invitation, Registro.Invitation

    # the branch to which the person acts as a volunteer or associate
    belongs_to :branch, Registro.Branch

    belongs_to :country, Registro.Country

    # the branches in which the person acts as an administrator
    many_to_many :admin_branches, Registro.Branch, join_through: "branches_admins"
  end

  @required_fields [ :first_name,
                     :last_name,
                     :legal_id_kind,
                     :legal_id_number,
                     :country_id,
                     :birth_date,
                     :occupation,
                     :address ]

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ [:status, :branch_id, :role, :is_super_admin])
    |> cast_assoc(:admin_branches, required: false)
    |> put_change(:filled, true)
    |> validate_required(@required_fields)
    |> validate_colaboration
  end

  def make_admin_changeset(datasheet, branches) do
    datasheet
    |> Registro.Repo.preload(:admin_branches)
    |> Ecto.Changeset.change
    |> Ecto.Changeset.put_assoc(:admin_branches, branches)
  end

  @doc """
  Create a new datasheet that is not filled.
  This means it is allowed to have all fields empty until a user completes it.
  """
  def new_empty_changeset() do
    %Datasheet{ filled: false }
    |> Ecto.Changeset.change
  end

  def pending_approval?(datasheet) do
    datasheet.status == "at_start"
  end

  def status_label(status) do
    case status do
      "at_start" -> "Pendiente"
      "approved" -> "Aprobado"
      "rejected" -> "Rechazado"
      nil        -> ""
    end
  end

  def role_label(datasheet) do
    datasheet = Registro.Repo.preload(datasheet, :admin_branches)

    cond do
      datasheet.is_super_admin -> "Administrador de Sede Central"
      Datasheet.is_branch_admin?(datasheet) -> "Administrador de Filial"
      Datasheet.is_volunteer?(datasheet) -> "Voluntario"
      Datasheet.is_associate?(datasheet) -> "Asociado"
      true -> ""
    end
  end

  def is_volunteer?(datasheet) do
    datasheet.role == "volunteer"
  end

  def is_associate?(datasheet) do
    datasheet.role == "associate"
  end

  def is_colaborator?(datasheet) do
    is_volunteer?(datasheet) or is_associate?(datasheet)
  end

  def is_admin?(datasheet) do
    datasheet.is_super_admin || is_branch_admin?(datasheet)
  end

  def is_branch_admin?(datasheet) do
    # load association if it hasn't been already loaded
    datasheet = Registro.Repo.preload(datasheet, :admin_branches)

    !Enum.empty?(datasheet.admin_branches)
  end

  def is_admin_of?(datasheet, %Branch{ id: branch_id }),
    do: is_admin_of?(datasheet, branch_id)

  def is_admin_of?(datasheet, branch_id) do
    # load association if it hasn't been already loaded
    datasheet = Registro.Repo.preload(datasheet, :admin_branches)

    datasheet.admin_branches
    |> Enum.any?(&(&1.id == branch_id))
  end

  def email(datasheet) do
    datasheet = Registro.Repo.preload(datasheet, [:user, :invitation])

    case datasheet do
      %Datasheet{ user: %User{email: email} } ->
        email

      %Datasheet{ invitation: %Invitation{ email: email } } ->
        email
    end
  end

  defp validate_colaboration(changeset) do
    # if a user participates as colaborator of branch, these three fields must be present
    role = Ecto.Changeset.get_field(changeset, :role)
    branch_id = Ecto.Changeset.get_field(changeset, :branch_id)
    status = Ecto.Changeset.get_field(changeset, :status)

    case {role, branch_id, status} do
      {nil, nil, nil} ->
        changeset
      _ ->
        changeset
        |> validate_required([:role, :branch_id, :status])
        |> validate_role
        |> validate_status
    end
  end

  defp validate_role(changeset) do
    role = Ecto.Changeset.get_field(changeset, :role)

    if role == "volunteer" || role == "associate" do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:role, "is invalid")
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

  def required_fields do
    @required_fields
  end

  def legal_id_kind(datasheet) do
    LegalIdKind.for_id(datasheet.legal_id_kind)
  end

  def full_name(datasheet) do
    "#{datasheet.first_name} #{datasheet.last_name}"
  end

  def full_query(q) do
    import Ecto.Query
    from d in q, preload: [:branch, :admin_branches, :country, :user]
  end

end
