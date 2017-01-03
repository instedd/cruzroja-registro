defmodule Registro.BranchesController do
  use Registro.Web, :controller

  alias Registro.Branch

  def index(conn, _params) do
    render(conn, "index.html", branches: Branch.all)
  end
end
