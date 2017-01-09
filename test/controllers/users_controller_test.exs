defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ControllerTestHelpers
  import Ecto.Query

  alias Registro.{User, Branch, Datasheet}

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
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is allowed to change the status of volunteers of the same branch", %{conn: conn} do
      setup_db

      {_conn, user} = try_approve(conn, "branch1@instedd.org", "volunteer@example.com")
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is not allowed to change the status of volunteers of other branches", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "branch2@instedd.org", "volunteer@example.com")

      assert html_response(conn, 302)
      assert user.datasheet.status == "at_start"
    end

    test "a volunteer is not allowed to change his status", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "volunteer@example.com", "volunteer@example.com")

      assert html_response(conn, 302)
      assert user.datasheet.status == "at_start"
    end

    def try_approve(conn, current_user_email, target_user_email) do
      volunteer = get_user_by_email(target_user_email)
      assert volunteer.datasheet.status == "at_start"

      update_params = %{
        user: %{
          datasheet: %{
            id: volunteer.datasheet.id,
            status: "approved"
          }}}

      conn = conn
      |> log_in(current_user_email)
      |> patch(users_path(Registro.Endpoint, :update, volunteer), update_params)

      volunteer = get_user_by_email(target_user_email)

      {conn, volunteer}
    end
  end

  describe "detail" do
    test "renders user detail", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer@example.com")

      conn = conn
      |> log_in("admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert html_response(conn, 200)
    end

    # TODO: authorization tests
  end

  describe "own profile" do
    test "renders admin's own profile", %{conn: conn} do
      setup_db

      user = get_user_by_email("admin@instedd.org")

      conn = conn
      |> log_in(user)
      |> get(users_path(Registro.Endpoint, :profile))

      response = html_response(conn, 200)

      assert response =~ user.email
      assert response =~ user.datasheet.name
    end

    test "renders volunteer own profile", %{conn: conn} do
      setup_db

      user = get_user_by_email("volunteer@example.com")

      conn = conn
      |> log_in(user)
      |> get(users_path(Registro.Endpoint, :profile))

      response = html_response(conn, 200)

      assert response =~ user.email
      assert response =~ user.datasheet.name
      assert response =~ Datasheet.status_label(user.datasheet.status)
      assert response =~ user.datasheet.branch.name
    end
  end

  describe "CSV download" do
    test "it allows downloading all users' information as CSV", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :download_csv))

      response = response(conn, 200)

      assert response == """
      Nombre,Email,Rol,Estado,Filial\r
      generated branch_admin,branch1@instedd.org,Administrador de Filial,,Branch 1\r
      generated branch_admin,branch2@instedd.org,Administrador de Filial,,Branch 2\r
      generated super_admin,admin@instedd.org,Administrador de Sede Central,,\r
      generated volunteer,volunteer@example.com,Voluntario,Pendiente,Branch 1\r
      """
    end
  end

  def get_user_by_email(email) do
    User.query_with_datasheet |> Repo.get_by!(email: email)
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
