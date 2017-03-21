defmodule Registro.Datasheet do
  use Registro.Web, :model

  alias __MODULE__
  alias Registro.User
  alias Registro.Branch
  alias Registro.Invitation

  import Registro.Gettext, only: [gettext: 1]

  @assocs [:branch, :admin_branches, :clerk_branches, :country, :user]

  schema "datasheets" do
    field :first_name, :string
    field :last_name, :string
    field :legal_id_kind, :string
    field :legal_id, :string
    field :birth_date, :date
    field :occupation, :string
    field :phone_number, :string
    field :registration_date, :date
    field :observations, :string
    field :address_street, :string
    field :address_number, :integer
    field :address_block, :string
    field :address_floor, :integer
    field :address_apartement, :string
    field :address_city, :string
    field :address_province, :string
    field :postal_code, :integer

    field :sigrid_profile_id, :integer
    field :extranet_profile_id, :integer

    field :status, :string
    field :role, :string
    field :is_paying_associate, :boolean
    field :global_grant, :string

    field :filled, :boolean
    field :branch_identifier, :integer

    has_one :user, Registro.User
    has_one :invitation, Registro.Invitation

    # the branch to which the person acts as a volunteer or associate
    belongs_to :branch, Registro.Branch

    belongs_to :country, Registro.Country

    # the branches in which the person acts as an administrator
    many_to_many :admin_branches, Registro.Branch, join_through: "branches_admins"

    # the branches in which the person acts as a clerk
    many_to_many :clerk_branches, Registro.Branch, join_through: "branches_clerks"
  end

  @required_fields [ :first_name,
                     :last_name,
                     :legal_id_kind,
                     :legal_id,
                     :country_id,
                     :birth_date,
                     :occupation,
                     :address_street,
                     :address_number,
                     :address_province,
                     :address_city,
                     :phone_number
                   ]

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ [:address_block, :address_floor, :address_province, :observations, :registration_date, :status, :branch_id, :role, :global_grant, :is_paying_associate])
    |> cast_assoc(:admin_branches, required: false)
    |> cast_assoc(:user, required: false)
    |> put_change(:filled, true)
    |> validate_required(@required_fields)
    |> validate_colaboration
    |> validate_global_grant
    |> validate_required_fields
    |> generate_identifier_on_branch_change
  end

  def registration_changeset(model, params \\ %{}) do
    model
    |> cast(%{status: "at_start"}, [:status])
    |> changeset(params)
    |> validate_required([:branch_id, :role])
    |> validate_colaboration
    |> validate_branch_is_eligible
  end

  def profile_filled_changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ [:registration_date, :address_block, :address_floor, :address_province])
    |> cast_assoc(:user, required: false, with: fn(model, params) -> User.changeset(model, :update, params) end)
    |> put_change(:filled, true)
    |> validate_required(@required_fields)
    |> validate_required_fields
  end

  def profile_update_changeset(model, params \\ %{}) do
    model
    |> cast(params, [:phone_number, :occupation, :address_street, :address_apartement, :address_number, :address_province, :address_city, :address_block, :address_floor, :address_province])
    |> cast_assoc(:user, required: false, with: fn(model, params) -> User.changeset(model, :update, params) end)
    |> validate_required([:phone_number, :occupation, :address_street, :address_province, :address_city, :address_province, :address_number])
  end

  def make_admin_changeset(datasheet, branches) do
    datasheet
    |> Registro.Repo.preload(:admin_branches)
    |> Ecto.Changeset.change
    |> Ecto.Changeset.put_assoc(:admin_branches, branches)
  end

  def make_clerk_changeset(datasheet, branches) do
    datasheet
    |> Registro.Repo.preload(:clerk_branches)
    |> Ecto.Changeset.change
    |> Ecto.Changeset.put_assoc(:clerk_branches, branches)
  end

  def associate_request_changeset(datasheet) do
    changeset(datasheet, %{ status: "associate_requested",
                            is_paying_associate: !registered_for_more_than_a_year?(datasheet) })
  end

  def validate_required_fields(changeset) do
    # these validations should be present every time @required_fields are casted
    changeset
    |> validate_legal_id
  end

  def validate_legal_id(changeset) do
    changeset = unique_constraint(changeset, :legal_id, name: :index_datasheets_on_legal_id)

    legal_id_kind = Ecto.Changeset.get_field(changeset, :legal_id_kind)
    legal_id = Ecto.Changeset.get_field(changeset, :legal_id)

    cond do
      legal_id_kind == "DNI" && !is_nil(legal_id)->
        formatted_number = String.replace(legal_id, ~r/\s|\./, "")
        case Integer.parse(formatted_number) do
          {_num, ""} ->
            put_change(changeset, :legal_id, formatted_number)
          _ ->
            changeset |> Ecto.Changeset.add_error(:legal_id, gettext "is not a valid number")
        end

      LegalIdKind.is_valid?(legal_id_kind) ->
        changeset

      true ->
        changeset |> Ecto.Changeset.add_error(:legal_id_kind, "is invalid")
    end
  end

  @doc """
  Create a new datasheet that is not filled.
  This means it is allowed to have all fields empty until a user completes it.
  """
  def new_empty_changeset() do
    %Datasheet{ filled: false }
    |> Ecto.Changeset.change
  end

  def status_label(status) do
    case status do
      "at_start" -> "Pendiente"
      "approved" -> "Aprobado"
      "rejected" -> "No aprobado"
      "associate_requested" -> "Solicitó ser asociado"
      nil        -> ""
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

  def is_staff?(datasheet) do
    has_global_access?(datasheet) || has_branch_access?(datasheet)
  end

  def has_global_access?(datasheet) do
    is_global_admin?(datasheet) || is_global_reader?(datasheet)
  end

  def has_branch_access?(datasheet) do
    is_branch_admin?(datasheet) || is_branch_clerk?(datasheet)
  end

  def is_global_admin?(datasheet) do
    datasheet.global_grant == "super_admin" || datasheet.global_grant == "admin"
  end

  def is_global_reader?(datasheet) do
    datasheet.global_grant == "reader"
  end

  def is_super_admin?(datasheet) do
    datasheet.global_grant == "super_admin"
  end

  def is_branch_admin?(datasheet) do
    datasheet = Registro.Repo.preload(datasheet, :admin_branches)

    !Enum.empty?(datasheet.admin_branches)
  end

  def is_branch_clerk?(datasheet) do
    datasheet = Registro.Repo.preload(datasheet, :clerk_branches)

    !Enum.empty?(datasheet.clerk_branches)
  end

  def is_clerk_of?(datasheet, %Branch{ id: branch_id }),
    do: is_clerk_of?(datasheet, branch_id)

  def is_clerk_of?(datasheet, branch_id) do
    datasheet = Registro.Repo.preload(datasheet, :clerk_branches)

    datasheet.clerk_branches
    |> Enum.any?(&(&1.id == branch_id))
  end

  def is_admin_of?(datasheet, %Branch{ id: branch_id }),
    do: is_admin_of?(datasheet, branch_id)

  def is_admin_of?(datasheet, branch_id) do
    # load association if it hasn't been already loaded
    datasheet = Registro.Repo.preload(datasheet, :admin_branches)

    datasheet.admin_branches
    |> Enum.any?(&(&1.id == branch_id))
  end

  def can_filter_by_branch?(datasheet) do
    datasheet = Registro.Repo.preload(datasheet, [:admin_branches, :clerk_branches])

    has_global_access?(datasheet)
    || Enum.count(datasheet.admin_branches) > 1
    || Enum.count(datasheet.clerk_branches) > 1
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
        |> validate_approved_colaborator_must_have_registration_date
        |> validate_associates_paying_flag
    end
  end

  defp generate_identifier_on_branch_change(changeset) do
    case Ecto.Changeset.get_change(changeset, :branch_id, :unchanged) do
      :unchanged ->
        changeset

      branch_id ->
        {:ok, identifier} = PgSql.next_datasheet_seq_num(branch_id)

        put_change(changeset, :branch_identifier, identifier)
    end
  end

  defp validate_branch_is_eligible(changeset) do
    branch_id = Ecto.Changeset.get_field(changeset, :branch_id)

    case branch_id do
      nil ->
        changeset
      _ ->
        case Registro.Repo.get(Branch, branch_id) do
          %Branch{ eligible: false } ->
            Ecto.Changeset.add_error(changeset, :branch_id, "is not eligible")
          _ ->
            changeset
        end
    end
  end

  defp validate_global_grant(changeset) do
    valid_values = ["super_admin", "admin", "reader", nil]
    grant = Ecto.Changeset.get_field(changeset, :global_grant)

    if Enum.member?(valid_values, grant) do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:global_grant, "is invalid")
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

  defp validate_associates_paying_flag(changeset) do
    is_associate = Ecto.Changeset.get_field(changeset, :role) == "associate"
    requested_associate = Ecto.Changeset.get_field(changeset, :status) == "associate_requested"
    is_paying_associate = Ecto.Changeset.get_field(changeset, :is_paying_associate)

    if is_nil(is_paying_associate) == (is_associate || requested_associate) do
      Ecto.Changeset.add_error(changeset, :is_paying_associate, "is invalid")
    else
      changeset
    end
  end

  def validate_approved_colaborator_must_have_registration_date(changeset) do
    role = Ecto.Changeset.get_field(changeset, :role)
    status = Ecto.Changeset.get_field(changeset, :status)
    registration_date = Ecto.Changeset.get_field(changeset, :registration_date)

    if !is_nil(role) do
      case {status, registration_date} do
        {"approved", nil} ->
          Ecto.Changeset.add_error(changeset, :registration_date, "is invalid")
        {"associate_requested", nil} ->
          # All volunteers in "associate_requested" state should have gone through
          # "approved" before. This validation is here just to catch bugs earlier,
          # specially in tests were we create fake values without going through
          # intermediate stages
          Ecto.Changeset.add_error(changeset, :registration_date, "is invalid")
        _ ->
          changeset
      end
    end

    case {role, status, registration_date} do
      {"volunteer", "approved", nil} ->
        Ecto.Changeset.add_error(changeset, :registration_date, "is invalid")
      {"volunteer", "associate_requested", nil} ->
        # All volunteers in "associate_requested" state should have gone through
        # "approved" before. This validation is here to catch errors earlier,
        # specially in tests were we create fake values without going through
        # intermediate stages
        Ecto.Changeset.add_error(changeset, :registration_date, "is invalid")
      _ ->
        changeset
    end
  end

  defp valid_status?(status) do
    Enum.member? ["at_start", "approved", "rejected", "associate_requested"], status
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
    from d in q, preload: ^@assocs
  end

  def full_query do
    full_query(Registro.Datasheet)
  end

  def preload_user(ds) do
    Registro.Repo.preload(ds, @assocs)
  end

  def can_ask_to_become_associate?(%Datasheet{ role: role, status: status }) do
    case {role, status} do
      { "volunteer", "approved" } ->
        true
      _ ->
        false
    end
  end

  def registered_for_more_than_a_year?(datasheet) do
    !(Registro.DateTime.less_than_a_year_ago?(datasheet.registration_date))
  end

end
