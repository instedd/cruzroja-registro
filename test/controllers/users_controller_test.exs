defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ControllerTestHelpers

  alias Registro.{User, Branch}

  test "verifies that user is logged in", %{conn: conn} do
    conn = get conn, "/usuarios"
    assert html_response(conn, 302)
  end

  test "non admin users are not allowed", %{conn: conn} do
    setup_db

    conn = conn
         |> log_in("volunteer@example.com")
         |> get("/usuarios")

    assert html_response(conn, 302)
  end

  test "super_admin can see all users", %{conn: conn} do
    setup_db

    conn = conn
          |> log_in("admin@instedd.org")
          |> get("/usuarios")

    assert html_response(conn, 200)

    result_count = Enum.count conn.assigns[:users]
    all_users_count = Repo.aggregate(User, :count, :id)

    assert result_count == all_users_count
  end

  test "branch admin can only see users if the same branch", %{conn: conn} do
    setup_db

    conn = conn
    |> log_in("branch1@instedd.org")
    |> get("/usuarios")

    assert html_response(conn, 200)

    user_emails = Enum.map conn.assigns[:users], &(&1.email)
    assert user_emails == ["branch1@instedd.org", "volunteer@example.com"]
  end

  def setup_db do
    create_branch(name: "Branch 1")
    create_branch(name: "Branch 2")

    [branch1, branch2] = Repo.all(from b in Branch, select: [:name, :id])

    create_user(email: "admin@instedd.org", role: "super_admin")
    create_user(email: "branch1@instedd.org", role: "branch_admin", branch_id: branch1.id)
    create_user(email: "branch2@instedd.org", role: "branch_admin", branch_id: branch2.id)

    create_user(email: "volunteer@example.com", role: "volunteer", branch_id: branch1.id)
  end
end
