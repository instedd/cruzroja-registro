defmodule Registro.AssociatePayment do
  use Registro.Web, :model

  alias __MODULE__

  schema "associate_payments" do
    field :date, :date
    belongs_to :datasheet, Registro.Datasheet

    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:date])
    |> cast_assoc(:datasheet, required: true)
    |> validate_required([:date])
  end
end

