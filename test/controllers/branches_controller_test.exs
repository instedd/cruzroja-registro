defmodule Registro.BranchesControllerTest do
  use Registro.ConnCase

  alias Registro.Branch
  alias Registro.User

  require IEx

  test "verifies that user is logged in", %{conn: conn} do
    conn = get conn, "/branches"
    assert html_response(conn, 302)
  end

  test "does not allow branch_admin", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("branch_admin")
    |> get("/branches")

    assert html_response(conn, 302)
  end

  test "displays all branches to super_admin user", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("super_admin")
    |> get("/branches")

    assert html_response(conn, 200)
    assert (Enum.count conn.assigns[:branches]) == 2
  end

  def setup_db do
    [
      %{name: "Branch 1", address: "Foo"},
      %{name: "Branch 2", address: "Bar"},
    ] |> Enum.map (fn params -> Branch.changeset(%Branch{}, params) |> Repo.insert! end)

    branch_id = Repo.get_by!(Branch, name: "Branch 1").id

    [
      %{name: "Admin", email: "admin@instedd.org", password: "admin", password_confirmation: "admin", role: "super_admin"},
      %{name: "Branch Admin", email: "branch@instedd.org", password: "admin", password_confirmation: "admin", role: "branch_admin", branch_id: branch_id},
    ] |> Enum.map (fn params -> User.changeset(%User{}, params) |> Repo.insert! end)
  end

  def log_in(conn, role) do
    user = Repo.get_by!(User, role: role)
    Plug.Conn.assign(conn, :current_user, user)
  end

end
