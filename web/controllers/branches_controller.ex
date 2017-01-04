defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias Registro.Repo
  alias Registro.Branch
  alias Registro.Pagination

  plug Registro.Authorization, check: &Registro.Role.is_admin?/1

  def index(conn, params) do
    page_count = Pagination.page_count(Branch)
    page = Pagination.requested_page(params, page_count)

    {template, conn} = case params["raw"] do
                       nil ->
                         { "index.html", conn }

                       _   ->
                         { "table.html", put_layout(conn, false) }
                     end

    render(conn, template,
      branches: Pagination.all(Branch, page_number: page),
      page: page,
      page_count: page_count,
      page_size: Pagination.default_page_size,
      total_count: Pagination.total_count(Branch)
    )
  end
end
