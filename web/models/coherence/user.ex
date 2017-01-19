defmodule Registro.User do
  use Registro.Web, :model
  use Coherence.Schema

  alias __MODULE__
  alias Registro.Repo

  schema "users" do
    field :email, :string
    coherence_schema
    belongs_to :datasheet, Registro.Datasheet

    timestamps
  end

  @doc """
  Changeset for user creation. A new datasheet will be created based on the
  information specified in params.
  """
  def changeset(:create_with_datasheet, params) do
    %User{}
    |> basic_changeset(params)
    |> cast_assoc(:datasheet, required: true)
  end

  @doc """
  Changeset for user creation that is to be associated with a preexisting
  datasheet.
  """
  def changeset(:create_from_invitation, invite, params) do
    params = Dict.merge(params, %{"email" => invite.email,
                                  "datasheet_id" => invite.datasheet.id})
    %User{}
    |> basic_changeset(params)
    |> cast(params, [:datasheet_id])
    |> validate_required([:datasheet_id])
  end

  @doc """
  Changeset that casts and validates user fields and any changes to the
  associated datasheet (if any).
  """
  def changeset(model, :update, params) do
    model
    |> basic_changeset(params)
    |> cast_assoc(:datasheet, required: false)
  end

  @doc """
  Unless modified, coherence controllers will use this function for creating
  changesets. Different changesets may be needed depending on the action.
  """
  def coherence_changeset(model, params, _which_controller) do
    changeset(model, :update, params)
  end

  defp basic_changeset(changeset, params) do
    changeset
    |> cast(params, [ :email | coherence_fields ])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_coherence(params)
  end

  def preload_datasheet(user) do
    Repo.preload(user, [datasheet: [:branch, :admin_branches, :country]])
  end

  def query_with_datasheet do
    query_with_datasheet(Registro.User)
  end

  def query_with_datasheet(q) do
    import Ecto.Query
    from u in q, preload: [datasheet: [:branch, :admin_branches, :country]]
  end
end
