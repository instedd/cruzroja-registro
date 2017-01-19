defmodule Registro.Invitation do
  use Coherence.Web, :model

  alias __MODULE__
  alias Registro.Datasheet

  schema "invitations" do
    field :name, :string
    field :email, :string
    field :token, :string

    belongs_to :datasheet, Registro.Datasheet

    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> base_changeset(params)
    |> cast_assoc(:datasheet, required: false)
  end

  def new_admin_changeset(email) do
    params = %{name: "-", email: email, datasheet: %{}}
    %Invitation{}
    |> base_changeset(params)
    |> generate_token
    |> cast_assoc(:datasheet, with: fn (_,_) -> Datasheet.new_empty_changeset end)
  end

  defp base_changeset(model, params) do
    model
    |> cast(params, ~w(name email token))
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
  end

  def generate_token(changeset) do
    token = Coherence.ControllerHelpers.random_string(48)
    put_change(changeset, :token, token)
  end

  def accept_url(invitation) do
    Registro.Router.Helpers.invitation_url(Registro.Endpoint, :edit, invitation.token)
  end

  def count do
    Registro.Repo.aggregate __MODULE__, :count, :id
  end
end
