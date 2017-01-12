defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.{User, Datasheet}

  describe "listing" do
    test "verifies that user is logged in", %{conn: conn} do
      conn = get conn, "/usuarios"
      assert html_response(conn, 302)
    end

    test "non admin users are not allowed", %{conn: conn} do
      setup_db

      conn = conn
          |> log_in("volunteer1@example.com")
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

    test "branch admin can only see users of his administrated branches", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/usuarios")

      assert html_response(conn, 200)

      user_emails = Enum.map conn.assigns[:users], &(&1.email)

      assert user_emails == ["branch_admin1@instedd.org", # self
                             "branch_admin3@instedd.org", # other admin of an administrated branch
                             "volunteer1@example.com",    # volunteer in an administrated branch
                             "volunteer3@example.com"     # ditto
                            ]
    end
  end

  describe "approval" do
    test "an super_admin is allowed to change the status of any volunteer", %{conn: conn} do
      setup_db

      {_conn, user} = try_approve(conn, "admin@instedd.org", "volunteer1@example.com")
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is allowed to change the status of volunteers of his administrated branches", %{conn: conn} do
      setup_db

      {_conn, user} = try_approve(conn, "branch_admin1@instedd.org", "volunteer1@example.com")
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is not allowed to change the status of volunteers of branches he doesn't adminstrate", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "branch_admin2@instedd.org", "volunteer1@example.com")

      assert html_response(conn, 302)
      assert user.datasheet.status == "at_start"
    end

    test "a volunteer is not allowed to change his status", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "volunteer1@example.com", "volunteer1@example.com")

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
    test "an admin can access any users detail", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert html_response(conn, 200)
    end

    test "a branch admin can access details of colaborators of administrated branches", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert html_response(conn, 200)
    end

    test "a branch admin can access details of other admins of administrated branches", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("branch_admin3@instedd.org")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert html_response(conn, 200)
    end

    test "a branch admin can not access details of colaborators of branches he doesn't administrate", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer2@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert html_response(conn, 302)
    end
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

      user = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in(user)
      |> get(users_path(Registro.Endpoint, :profile))

      response = html_response(conn, 200)

      assert response =~ user.email
      assert response =~ user.datasheet.name
      assert response =~ String.upcase Datasheet.status_label(user.datasheet.status)
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
      Nombre,Email,Filial,Rol,Estado\r
      admin,admin@instedd.org,,,\r
      branch_admin1,branch_admin1@instedd.org,,,\r
      branch_admin2,branch_admin2@instedd.org,,,\r
      branch_admin3,branch_admin3@instedd.org,,,\r
      volunteer1,volunteer1@example.com,Branch 1,Voluntario,Pendiente\r
      volunteer2,volunteer2@example.com,Branch 2,Voluntario,Pendiente\r
      volunteer3,volunteer3@example.com,Branch 3,Voluntario,Pendiente\r
      """
    end
  end

  def get_user_by_email(email) do
    User.query_with_datasheet |> Repo.get_by!(email: email)
  end

  def setup_db do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")
    branch3 = create_branch(name: "Branch 3")

    create_super_admin(email: "admin@instedd.org")
    create_branch_admin(email: "branch_admin1@instedd.org", branches: [branch1, branch3])
    create_branch_admin(email: "branch_admin2@instedd.org", branch: branch2)
    create_branch_admin(email: "branch_admin3@instedd.org", branch: branch3)

    create_user(email: "volunteer1@example.com", role: "volunteer", branch_id: branch1.id)
    create_user(email: "volunteer2@example.com", role: "volunteer", branch_id: branch2.id)
    create_user(email: "volunteer3@example.com", role: "volunteer", branch_id: branch3.id)
  end
end
