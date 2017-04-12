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
    |> unique_constraint(:date)
    |> validate_required([:date])
  end

  def for(list, date) do
    {:ok, formatted} = Elixir.Date.new(date.year, date.month, date.day)
    case Enum.find(list, nil, fn act -> act.date == formatted end) do
      nil -> false
      found -> true
    end
  end
end

