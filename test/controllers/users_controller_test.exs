defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ControllerTestHelpers

  alias Registro.{User, Branch}

  describe "listing" do
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
  end

  describe "approval" do
    test "an super_admin is allowed to change the status of any volunteer", %{conn: conn} do
      setup_db

      {_conn, user} = try_approve(conn, "admin@instedd.org", "volunteer@example.com")
      assert user.status == "approved"
    end

    test "a branch admin is allowed to change the status of volunteers of the same branch", %{conn: conn} do
      setup_db

      {_conn, user} = try_approve(conn, "branch1@instedd.org", "volunteer@example.com")
      assert user.status == "approved"
    end

    test "a branch admin is not allowed to change the status of volunteers of other branches", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "branch2@instedd.org", "volunteer@example.com")

      assert html_response(conn, 302)
      assert user.status == "at_start"
    end

    test "a volunteer is not allowed to change his status", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "volunteer@example.com", "volunteer@example.com")

      assert html_response(conn, 302)
      assert user.status == "at_start"
    end

    def try_approve(conn, current_user_email, target_user_email) do
      volunteer = Repo.get_by!(User, email: target_user_email)
      assert volunteer.status == "at_start"

      conn = conn
      |> log_in(current_user_email)
      |> patch(users_path(Registro.Endpoint, :update, volunteer), user: %{ status: "approved" })

      volunteer = Repo.get_by!(User, email: target_user_email)

      {conn, volunteer}
    end
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
