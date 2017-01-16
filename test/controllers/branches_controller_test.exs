defmodule Registro.BranchesControllerTest do
  use Registro.ConnCase

  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.Branch

  describe "listing" do
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

    test "displays all branches to super_admin user", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("admin@instedd.org")
      |> get("/filiales")

      assert html_response(conn, 200)
      assert (Enum.count conn.assigns[:branches]) == 2
    end

    test "branch admin can only see his administrated branches", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("branch1@instedd.org")
      |> get("/filiales")

      assert html_response(conn, 200)

      branch_names = conn.assigns[:branches]
      |> Enum.map(&(&1.name))

      assert branch_names == ["Branch 1"]
    end
  end

  test "a branch admin cannot access a branch he doesn't administrate", %{conn: conn} do
    setup_db

    branch2 = Repo.get_by!(Branch, name: "Branch 2")

    conn = conn
         |> log_in("branch1@instedd.org")
         |> get(branches_path(conn, :show, branch2))

    assert_unauthorized(conn)
  end

  def setup_db do
    branch1 = create_branch(name: "Branch 1")
    _branch2 = create_branch(name: "Branch 2")

    create_user(email: "john@example.com", role: "volunteer", branch_id: branch1.id)
    create_super_admin(email: "admin@instedd.org")
    create_branch_admin(email: "branch1@instedd.org", branch: branch1)
  end

end
