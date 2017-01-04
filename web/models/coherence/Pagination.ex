defmodule Registro.Pagination do

  import Ecto.Query

  @default_page_size 8

  def query(module, page_number: page_number) do
    query(module, page_number: page_number, page_size: @default_page_size)
  end

  def query(module, page_number: page_number, page_size: page_size) do
    q = from e in module
    restrict(q, page_number: page_number, page_size: page_size)
  end

  def restrict(q, page_number: page_number) do
    restrict(q, page_number: page_number, page_size: @default_page_size)
  end

  def restrict(q, page_number: page_number, page_size: page_size) do
    offset = (page_number - 1) * page_size

    from e in q,
      offset: ^offset,
      limit: ^page_size,
      order_by: :name
  end

  def all(module, opts) do
    query(module, opts) |> Registro.Repo.all
  end

  def default_page_size do
    @default_page_size
  end

  def total_count(module) do
    Registro.Repo.one(from e in module, select: count(e.id))
  end

  def page_count(module) do
    page_count(module, page_size: @default_page_size)
  end

  def page_count(module, page_size: page_size) do
    round(Float.ceil(total_count(module) / page_size))
  end

  def requested_page(params, page_count) do
    (params["page"] || "1")
      |> String.to_integer
      |> min(page_count)
  end
end
