defmodule Registro.VolunteerActivity do
  use Registro.Web, :model

  schema "volunteer_activity" do
    field :date, :date
    field :description, :string
    belongs_to :datasheet, Registro.Datasheet

    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:date, :description])
    |> cast_assoc(:datasheet, required: true)
    |> unique_constraint(:date)
    |> validate_required([:date, :description])
  end

  def is_saved(date, desc, activities_list) do
    Enum.find(activities_list, fn(act) -> act.date == date && act.description == desc end)
  end

  def desc_for(list, date) do
    {:ok, formatted} = Elixir.Date.new(date.year, date.month, date.day)
    case Enum.find(list, nil, fn act -> act.date == formatted end) do
      nil -> nil
      found -> found.description
    end
  end

end

