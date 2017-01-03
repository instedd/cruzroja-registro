defmodule Registro.Branch do
  use Registro.Web, :model
  @derive {Poison.Encoder, only: [:name, :id]}

  @default_page_size 8

  schema "branches" do
    field :name, :string
    field :address, :string
    timestamps
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name, :address])
    |> validate_required([:name, :address])
    |> unique_constraint(:name)
  end

  def all do
    Registro.Repo.all(from b in Registro.Branch, select: b, order_by: :name)
  end

  def all(page_number: page_number) do
    all(page_number: page_number, page_size: @default_page_size)
  end

  def all(page_number: page_number, page_size: page_size) do
    offset = (page_number - 1) * page_size

    Registro.Repo.all(from b in Registro.Branch,
                      offset: ^offset,
                      limit: ^page_size,
                      order_by: :name)
  end

  def page_count do
    page_count(page_size: @default_page_size)
  end

  def page_count(page_size: page_size) do
    round(Float.ceil(count / page_size))
  end

  def default_page_size do
    @default_page_size
  end

  def count do
    Registro.Repo.one(from b in Registro.Branch, select: count(b.id))
  end
end
