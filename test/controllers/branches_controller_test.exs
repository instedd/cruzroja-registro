defmodule Registro.BranchesControllerTest do
  use Registro.ConnCase

  import Registro.ControllerTestHelpers

  alias Registro.Branch

  test "verifies that user is logged in", %{conn: conn} do
    conn = get conn, "/filiales"
    assert html_response(conn, 302)
  end

  test "does not allow branch_admin", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("branch@instedd.org")
    |> get("/filiales")

    assert html_response(conn, 302)
  end

  test "displays all branches to super_admin user", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("admin@instedd.org")
    |> get("/filiales")

    assert html_response(conn, 200)
    assert (Enum.count conn.assigns[:branches]) == 2
  end

  def setup_db do
    create_branch(name: "Branch 1")
    create_branch(name: "Branch 2")

    branch_id = Repo.get_by!(Branch, name: "Branch 1").id

    create_user(email: "admin@instedd.org", role: "super_admin")
    create_user(email: "branch@instedd.org", role: "branch_admin", branch_id: branch_id)
  end

end
