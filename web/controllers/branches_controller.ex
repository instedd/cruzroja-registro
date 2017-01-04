defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias Registro.Branch

  plug Registro.Authorization, check: &Registro.Role.is_admin?/1

  def index(conn, params) do
    page_count = Branch.page_count

    page = (params["page"] || "1")
            |> String.to_integer
            |> min(page_count)

    branches = Branch.all(page_number: page)

    {template, conn} = case params["raw"] do
                       nil ->
                         { "index.html", conn }

                       _   ->
                         { "table.html", put_layout(conn, false) }
                     end

    render(conn, template,
      branches: branches,
      page: page,
      page_count: page_count,
      page_size: Branch.default_page_size,
      total_count: Branch.count
    )
  end
end
