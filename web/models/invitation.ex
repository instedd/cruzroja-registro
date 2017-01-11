defmodule Registro.Invitation do
  use Coherence.Web, :model

  schema "invitations" do
    field :name, :string
    field :email, :string
    field :token, :string

    belongs_to :datasheet, Registro.Datasheet

    timestamps
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(name email token))
    |> cast_assoc(:datasheet, required: false)
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
  end

  def count do
    Registro.Repo.aggregate __MODULE__, :count, :id
  end
end