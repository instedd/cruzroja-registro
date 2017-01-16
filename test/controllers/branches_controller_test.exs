defmodule Registro.BranchesControllerTest do
  use Registro.ConnCase

  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  test "verifies that user is logged in", %{conn: conn} do
    conn = get conn, "/filiales"
    assert redirected_to(conn) == "/"
  end

  test "does not allow non-admin users", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("john@example.com")
    |> get("/filiales")

    assert_unauthorized(conn)
  end

  test "does not allow branch_admin", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("branch@instedd.org")
    |> get("/filiales")

    assert_unauthorized(conn)
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
    branch1 = create_branch(name: "Branch 1")
    _branch2 = create_branch(name: "Branch 2")

    create_user(email: "john@example.com", role: "volunteer", branch_id: branch1.id)
    create_super_admin(email: "admin@instedd.org")
    create_branch_admin(email: "branch@instedd.org", branch: branch1)
  end

end
