defmodule Registro.User do
  use Registro.Web, :model
  use Coherence.Schema

  alias __MODULE__
  alias Registro.Repo
  alias Registro.Role

  schema "users" do
    field :email, :string
    coherence_schema
    belongs_to :datasheet, Registro.Datasheet

    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [ :email | coherence_fields])
    |> cast_assoc(:datasheet, required: false)
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_coherence(params)
  end

  def role_label(role) do
    Registro.Role.label(role)
  end

  def preload_datasheet(user) do
    Repo.preload(user, [datasheet: [:branch]])
  end

  def query_with_datasheet do
    query_with_datasheet(Registro.User)
  end

  def query_with_datasheet(q) do
    import Ecto.Query
    from u in q, preload: [datasheet: [:branch]]
  end
end
