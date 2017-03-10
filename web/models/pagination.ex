defmodule Registro.Pagination do

  import Ecto.Query

  @default_page_size 25

  def query(q, page_number: page_number) do
    query(q, page_number: page_number, page_size: @default_page_size)
  end

  def query(q, page_number: page_number, page_size: page_size) do
    offset = (page_number - 1) * page_size

    from e in q,
      offset: ^offset,
      limit: ^page_size
  end

  def default_page_size do
    @default_page_size
  end

  def page_count(total_count) do
    page_count(total_count, page_size: @default_page_size)
  end

  def page_count(total_count, page_size: page_size) do
    round(Float.ceil(total_count / page_size))
  end

  def requested_page(params) do
    (params["page"] || "1") |> String.to_integer
  end
end
