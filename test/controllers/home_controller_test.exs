defmodule Registro.HomeControllerTest do
  use Registro.ConnCase

  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  setup(context) do
    create_country("Argentina")

    {:ok, context}
  end

  test "redirects non-authenticated requests to login page", %{conn: conn} do
    conn = get(conn, "/")

    assert html_response(conn, 200) =~ "Iniciar sesión"
  end

  test "redirects colaborators to their profile", %{conn: conn} do
    branch = create_branch(name: "Branch")
    volunteer = create_volunteer("volunteer@example.com", branch.id)

    conn = request_home_as(conn, volunteer)

    assert redirected_to(conn) == "/perfil"
  end

  test "redirects branch_admin to users listing", %{conn: conn} do
    branch = create_branch(name: "Branch")
    branch_admin = create_branch_admin("admin@instedd.org", branch)

    conn = request_home_as(conn, branch_admin)

    assert redirected_to(conn) == "/usuarios"
  end

  test "redirects super_admin to usersl listing", %{conn: conn} do
    super_admin = create_super_admin("admin@instedd.org")
    conn = request_home_as(conn, super_admin)

    assert redirected_to(conn) == "/usuarios"
  end

  defp request_home_as(conn, user) do
    conn |> log_in(user) |> get("/")
  end
end
