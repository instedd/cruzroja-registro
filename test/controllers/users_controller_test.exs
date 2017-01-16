defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.{User, Datasheet, Branch}

  describe "listing" do
    test "verifies that user is logged in", %{conn: conn} do
      conn = get conn, "/usuarios"

      assert redirected_to(conn) == "/"
    end

    test "non admin users are not allowed", %{conn: conn} do
      setup_db

      conn = conn
          |> log_in("volunteer1@example.com")
          |> get("/usuarios")

      assert_unauthorized(conn)
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

    test "branch admin can only see colaborators of his administrated branches", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/usuarios")

      assert html_response(conn, 200)

      user_emails = Enum.map conn.assigns[:users], &(&1.email)

      assert user_emails == ["volunteer1@example.com",
                             "volunteer3@example.com"
                            ]
    end
  end

  describe "update" do
    test "a super_admin can update a user's branch", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{
        branch_name: "Branch 2",
        user: %{
          datasheet: %{ id: volunteer.datasheet.id, role: "associate" }
        }}

      {_conn, volunteer} = update_user(conn, "admin@instedd.org", volunteer, params)

      assert volunteer.datasheet.role == "associate"
      assert volunteer.datasheet.branch.name == "Branch 2"
    end

    test "a branch admin cannot update a user's branch", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{
        branch_name: "Branch 2",
        user: %{
          datasheet: %{ id: volunteer.datasheet.id, role: "associate" }
        }}

      {_conn, updated_volunteer} = update_user(conn, "branch_admin1@instedd.org", volunteer, params)

      assert volunteer == updated_volunteer
    end

    test "a branch admin can change role of colaborations of the same branch", %{conn: conn} do
      setup_db

      u1 = get_user_by_email("branch_admin1@instedd.org")
      u2 = get_user_by_email("volunteer1@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ user:
                  %{ :datasheet => %{
                  id: u2.datasheet.id,
                  role: "associate",
                  status: u2.datasheet.status }}}

      {_conn, u2} = update_user(conn, u1, u2, params)

      assert u2.datasheet.role == "associate"
    end

    test "a branch admin can't change role of colaborations of other branches", %{conn: conn} do
      setup_db

      u1 = get_user_by_email("branch_admin1@instedd.org")
      u2 = get_user_by_email("volunteer2@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ user:
                  %{ :datasheet => %{
                  id: u2.datasheet.id,
                  role: "associate",
                  status: u2.datasheet.status }}}

      {conn, _u2} = update_user(conn, u1, u2, params)

      assert_unauthorized(conn)
    end
  end

  describe "status changes" do
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

      assert_unauthorized(conn)
      assert user.datasheet.status == "at_start"
    end

    test "a volunteer is not allowed to change his status", %{conn: conn} do
      setup_db

      {conn, user} = try_approve(conn, "volunteer1@example.com", "volunteer1@example.com")

      assert_unauthorized(conn)
      assert user.datasheet.status == "at_start"
    end

    def try_approve(conn, current_user_email, target_user_email) do
      volunteer = get_user_by_email(target_user_email)

      assert volunteer.datasheet.status == "at_start"

      params = %{
        user: %{
          datasheet: %{
            id: volunteer.datasheet.id,
            status: "approved"
          }}}

      {conn, volunteer} = update_user(conn, current_user_email, volunteer, params)

      {conn, volunteer}
    end
  end

  # A super admin should be allowed to mark a user with no previous branch
  # colaboration (ie. other admins) as a colaborator of any branch.
  describe "marking users as colaborators of a branch after registration" do
    test "the colaboration is assumed approved when set by a super_admin", %{conn: conn} do
      setup_db

      %{datasheet: datasheet} = user = get_user_by_email("branch_admin1@instedd.org")

      branch2 = Repo.get_by(Branch, name: "Branch 2")

      {nil, nil, nil} = {datasheet.branch_id, datasheet.role, datasheet.status}

      params = %{
        user: %{
          datasheet: %{ id: user.datasheet.id, branch_id: branch2.id, role: "volunteer" }
        }}

      {_conn, user} = update_user(conn, "admin@instedd.org", user, params)

      assert user.datasheet.branch_id == branch2.id
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
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

    test "a branch admin can not access details of other admins of administrated branches", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("branch_admin3@instedd.org")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert_unauthorized(conn)
    end

    test "a branch admin can not access details of colaborators of branches he doesn't administrate", %{conn: conn} do
      setup_db

      volunteer = get_user_by_email("volunteer2@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert_unauthorized(conn)
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

  def update_user(conn, %User{} = current_user, target_user, params) do
    conn = conn
    |> log_in(current_user)
    |> patch(users_path(Registro.Endpoint, :update, target_user), params)

    {conn, Repo.get(User.query_with_datasheet, target_user.id)}
  end
  def update_user(conn, current_user_email, target_user, params) do
    update_user(conn, get_user_by_email(current_user_email), target_user, params)
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
