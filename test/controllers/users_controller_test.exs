defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.{User, Datasheet, Branch}

  setup(context) do
    country = create_country("Argentina")

    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")
    branch3 = create_branch(name: "Branch 3")

    create_super_admin("admin@instedd.org")

    create_branch_admin("branch_admin1@instedd.org", [branch1, branch3])
    create_branch_admin("branch_admin2@instedd.org", branch2)
    create_branch_admin("branch_admin3@instedd.org", branch3)

    volunteer1 = create_volunteer("volunteer1@example.com", branch1.id)
    volunteer2 = create_volunteer("volunteer2@example.com", branch2.id)
    volunteer3 = create_volunteer("volunteer3@example.com", branch3.id)

    # TODO: pass the desired status when creating the user
    # These asserts are here because status change specs assume volunteers start in "at_start" state
    assert volunteer1.datasheet.status == "at_start"
    assert volunteer2.datasheet.status == "at_start"
    assert volunteer3.datasheet.status == "at_start"

    {:ok, Map.merge(%{ some_country: country, some_branch: branch1 }, context)}
  end

  describe "listing" do
    test "verifies that user is logged in", %{conn: conn} do
      conn = get conn, "/usuarios"

      assert redirected_to(conn) == "/"
    end

    test "non admin users are not allowed", %{conn: conn} do
      conn = conn
          |> log_in("volunteer1@example.com")
          |> get("/usuarios")

      assert_unauthorized(conn)
    end

    test "super_admin can see all users", %{conn: conn} do
      conn = conn
            |> log_in("admin@instedd.org")
            |> get("/usuarios")

      assert html_response(conn, 200)

      result_count = Enum.count conn.assigns[:datasheets]
      all_users_count = Repo.aggregate(User, :count, :id)

      assert result_count == all_users_count
    end

    test "branch admin can only see colaborators of his administrated branches", %{conn: conn} do
      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/usuarios")

      assert html_response(conn, 200)

      user_emails = Enum.map conn.assigns[:datasheets], &(&1.user.email)

      assert Enum.sort(user_emails) == ["volunteer1@example.com",
                                        "volunteer3@example.com"
                                       ]
    end
  end

  describe "own user's profile" do
    test "an invited branch admin is redirected to profile page upon navigation until his datasheet is filled", %{conn: conn, some_branch: branch} do
      user = create_invited_admin(branch)

      conn = conn
           |> log_in(user)
           |> get(users_path(conn, :index))

      assert redirected_to(conn) == users_path(conn, :profile)
    end

    test "profile page with form is rendered even if datasheed isn't filled", %{conn: conn, some_branch: branch} do
      # this basically test that we don't enter a redirect loop
      user = create_invited_admin(branch)

      conn = conn
           |> log_in(user)
           |> get(users_path(conn, :profile))

      assert html_response(conn, 200)
    end

    test "allow the user to logout without filling the datasheet", %{conn: conn, some_branch: branch} do
      user = create_invited_admin(branch)

      conn = conn
      |> log_in(user)
      |> delete(session_path(conn, :delete))

      assert html_response(conn, 302)
      assert redirected_to(conn) == "/"
    end

    test "a user can edit his datasheet fields when first filling his datasheet", %{conn: conn, some_branch: branch, some_country: country} do
      user = create_invited_admin(branch)

      {conn, updated_user} = update_profile(conn, user, %{datasheet: datasheet_submission(country.id)})

      assert redirected_to(conn) == users_path(conn, :profile)

      assert updated_user.datasheet.filled

      %Datasheet{
        first_name: "John",
        last_name: "Doe",
        legal_id_kind: "DNI",
        legal_id_number: "1234567890",
        birth_date: ~D[1990-01-01],
        occupation: "occupation...",
        address: "address...",
        phone_number: "+111",
        country: ^country,
      } = updated_user.datasheet
    end

    test "collaboration settings can not be updated in profile endpoint", %{conn: conn, some_branch: branch, some_country: country} do
      user = create_invited_admin(branch)

      params = datasheet_submission(country.id)
             |> Map.merge(%{role: "volunteer",
                            status: "at_start",
                            branch_id: branch.id
                           })
      {conn, updated_user} = update_profile(conn, user, %{datasheet: params})

      assert redirected_to(conn) == users_path(conn, :profile)

      assert updated_user.datasheet.role == nil
      assert updated_user.datasheet.branch_id == nil
      assert updated_user.datasheet.status == nil
    end

    test "email, phone number, occupation and address can be edited after filling the datasheet", %{conn: conn} do
      user = Repo.get_by!(User, email: "branch_admin1@instedd.org")

      params = %{datasheet: %{
                    phone_number: "phone number...",
                    occupation: "occupation...",
                    address: "address...",
                    user: %{ id: "#{user.id}",
                             email: "modified_email@instedd.org" }}}

      {conn, updated_user} = update_profile(conn, user, params)

      assert redirected_to(conn) == users_path(conn, :profile)

      assert updated_user.email == "modified_email@instedd.org"
      assert updated_user.datasheet.phone_number == "phone number..."
      assert updated_user.datasheet.occupation == "occupation..."
      assert updated_user.datasheet.address == "address..."
    end

    test "it is not possible to change datasheet>user association", %{conn: conn} do
      user = Repo.get_by!(User, email: "branch_admin1@instedd.org")
      other_user = Repo.get_by!(User, email: "branch_admin2@instedd.org")

      params = %{datasheet: %{ user: %{ id:  "#{other_user.id}" }}}

      {conn, _} = update_profile(conn, user, params)

      assert_unauthorized(conn)

      updated_user = Repo.get_by!(User, email: "branch_admin1@instedd.org")
      updated_other_user = Repo.get_by!(User, email: "branch_admin2@instedd.org")

      assert user == updated_user
      assert other_user == updated_other_user
    end

    test "other fields cannot be updated once the datasheet has been filled", %{conn: conn} do
      user = Repo.get_by!(User, email: "branch_admin1@instedd.org")
           |> User.preload_datasheet

      params = %{datasheet: %{ first_name: "This cannot be changed", is_super_admin: true }}

      {conn, updated_user} = update_profile(conn, user, params)

      assert redirected_to(conn) == users_path(conn, :profile)
      assert user == updated_user
    end

    def update_profile(conn, user, params) do
      conn = conn
      |> log_in(user)
      |> put(users_path(conn, :update_profile), params)

      updated_user = (from u in User, preload: [datasheet: :country])
      |> Repo.get!(user.id)
      |> User.preload_datasheet

      {conn, updated_user}
    end

    def datasheet_submission(country_id) do
      %{
        first_name: "John",
        last_name: "Doe",
        legal_id_kind: "DNI",
        legal_id_number: "1234567890",
        birth_date: "1990-01-01",
        occupation: "occupation...",
        address: "address...",
        phone_number: "+111",
        country_id: country_id,
      }
    end

    def create_invited_admin(branch) do
      invite = Registro.Invitation.new_admin_changeset("user@example.com")
      |> Repo.insert!

      user = User.changeset(:create_from_invitation, invite, %{ "password" => "123456", "password_confirmation" => "123456" })
      |> Repo.insert!
      |> Repo.preload(:datasheet)

      branch
      |> Repo.preload(:admins)
      |> Branch.changeset(%{})
      |> Branch.update_admins([user.datasheet])
      |> Repo.update!

      user
    end
  end

  describe "updating managed datasheets" do
    test "a super_admin can update a user's branch", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{
        branch_name: "Branch 2",
        datasheet: %{ id: volunteer.datasheet.id, role: "associate" }
      }

      {_conn, volunteer} = update_user(conn, "admin@instedd.org", volunteer, params)

      assert volunteer.datasheet.role == "associate"
      assert volunteer.datasheet.branch.name == "Branch 2"
    end

    test "a branch admin cannot update a user's branch", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{
        branch_name: "Branch 2",
        datasheet: %{ id: volunteer.datasheet.id, role: "associate" }
        }

      {_conn, updated_volunteer} = update_user(conn, "branch_admin1@instedd.org", volunteer, params)

      assert volunteer == updated_volunteer
    end

    test "a branch admin can change role of colaborations of the same branch", %{conn: conn} do
      u1 = get_user_by_email("branch_admin1@instedd.org")
      u2 = get_user_by_email("volunteer1@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ :datasheet => %{
                  id: u2.datasheet.id,
                  role: "associate",
                  status: u2.datasheet.status }}

      {_conn, u2} = update_user(conn, u1, u2, params)

      assert u2.datasheet.role == "associate"
    end

    test "a branch admin can't change role of colaborations of other branches", %{conn: conn} do
      u1 = get_user_by_email("branch_admin1@instedd.org")
      u2 = get_user_by_email("volunteer2@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ :datasheet => %{
                  id: u2.datasheet.id,
                  role: "associate",
                  status: u2.datasheet.status }}

      {conn, _u2} = update_user(conn, u1, u2, params)

      assert_unauthorized(conn)
    end
  end

  describe "status changes" do
    test "an super_admin is allowed to change the status of any volunteer", %{conn: conn} do
      {_conn, user} = try_approve(conn, "admin@instedd.org", "volunteer1@example.com")
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is allowed to change the status of volunteers of his administrated branches", %{conn: conn} do
      {_conn, user} = try_approve(conn, "branch_admin1@instedd.org", "volunteer1@example.com")
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is not allowed to change the status of volunteers of branches he doesn't adminstrate", %{conn: conn} do
      {conn, user} = try_approve(conn, "branch_admin2@instedd.org", "volunteer1@example.com")

      assert_unauthorized(conn)
      assert user.datasheet.status == "at_start"
    end

    test "a volunteer is not allowed to change his status", %{conn: conn} do
      {conn, user} = try_approve(conn, "volunteer1@example.com", "volunteer1@example.com")

      assert_unauthorized(conn)
      assert user.datasheet.status == "at_start"
    end

    test "a super_admin is allowed to approve requests from volunteers to become associates", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      volunteer = User.changeset(volunteer, :update, %{ datasheet: %{ id: volunteer.datasheet.id, status: "associate_requested" } })
                |> Repo.update!

      {_conn, user} = try_approve(conn, "admin@instedd.org", volunteer)

      assert user.datasheet.role == "associate"
      assert user.datasheet.status == "approved"
    end

    def try_approve(conn, current_user_email, %User{} = volunteer) do
      params = %{
          email: volunteer.email,
          flow_action: "approve",
          datasheet: %{
            id: volunteer.datasheet.id,
          }}

      update_user(conn, current_user_email, volunteer, params)
    end

    def try_approve(conn, current_user_email, target_user_email) do
      volunteer = get_user_by_email(target_user_email)
      try_approve(conn, current_user_email, volunteer)
    end
  end

  describe "volunteer transition to associate" do
    test "an approved volunteer can ask to become associate", %{conn: conn, some_branch: branch} do
      {conn, user} = create_approved_volunteer(branch)
                    |> request_volunteer_update(conn)

      assert redirected_to(conn) == users_path(Registro.Endpoint, :profile)
      assert user.datasheet.status == "associate_requested"
    end

    test "an audit entry is created when the user requests to become associate", %{conn: conn, some_branch: branch} do
      {_conn, user} = create_approved_volunteer(branch)
                    |> request_volunteer_update(conn)

      audit_entries = Registro.UserAuditLogEntry.for(user.datasheet, "associate_requested")

      assert Enum.count(audit_entries) == 1
    end

    def request_volunteer_update(volunteer, conn) do
      conn = conn
      |> log_in(volunteer)
      |> post(users_path(Registro.Endpoint, :associate_request))

      updated_volunteer = Repo.get(User.query_with_datasheet, volunteer.id)

      {conn, updated_volunteer}
    end

    def create_approved_volunteer(branch) do
      user = create_volunteer("approved_volunteer@example.com", branch.id)

      user
      |> Ecto.Changeset.change
      |> Ecto.Changeset.put_assoc(:datasheet, %{ id: user.datasheet.id, status: "approved"  })
      |> Repo.update!
    end

    def a_year_ago do
      { date, _time } = Timex.Date.today |> Timex.shift(years: -1, days: -1) |> Timex.to_erlang_datetime
      Ecto.Date.from_erl(date)
    end

    def less_than_a_year_ago do
      Ecto.Date.utc
    end
  end

  # A super admin should be allowed to mark a user with no previous branch
  # colaboration (ie. other admins) as a colaborator of any branch.
  describe "marking users as colaborators of a branch after registration" do
    test "the colaboration is assumed approved when set by a super_admin", %{conn: conn} do
      %{datasheet: datasheet} = user = get_user_by_email("branch_admin1@instedd.org")

      branch2 = Repo.get_by(Branch, name: "Branch 2")

      {nil, nil, nil} = {datasheet.branch_id, datasheet.role, datasheet.status}

      params = %{
          email: user.email,
          datasheet: %{ id: user.datasheet.id, branch_id: branch2.id, role: "volunteer" }
        }

      {_conn, user} = update_user(conn, "admin@instedd.org", user, params)

      assert user.datasheet.branch_id == branch2.id
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
    end
  end

  describe "granting super_admin permissions" do
    test "a super_admin can grant super_admin permissions to other users", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {_conn, user} = update_user(conn, "admin@instedd.org", volunteer, datasheet: %{
                                                                            id: volunteer.datasheet.id,
                                                                            is_super_admin: true })

      assert user.datasheet.is_super_admin
    end

    test "a super_admin can revoke super_admin permissions to other users", %{conn: conn} do
      other_admin = create_super_admin("admin2@instedd.org")

      {_conn, other_admin} = update_user(conn, "admin@instedd.org", other_admin, datasheet: %{
                                                                                    id: other_admin.datasheet.id,
                                                                                    is_super_admin: false })

      refute other_admin.datasheet.is_super_admin
    end

    test "a super_admin cannot revoke his own super_admin permissions", %{conn: conn} do
      admin = get_user_by_email("admin@instedd.org")

      {_conn, admin} = update_user(conn, admin, admin, datasheet: %{
                                                                  id: admin.datasheet.id,
                                                                  is_super_admin: false })

      assert admin.datasheet.is_super_admin
    end

    test "a super_admin can edit his own fields", %{conn: conn} do
      # bugfix: value for is_super_admin reaches the controller
      # as the string "true" instead of the boolean value.
      # this caused problems when checking if the flag changed.
      admin = get_user_by_email("admin@instedd.org")

      {_conn, admin} = update_user(conn, admin, admin, datasheet: %{
                                                                  id: admin.datasheet.id,
                                                                  first_name: "foo",
                                                                  is_super_admin: "true" })

      assert admin.datasheet.is_super_admin
      assert admin.datasheet.first_name == "foo"
    end

    test "a branch admin cannot grant super_admin permission", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      params = %{ datasheet: %{ id: volunteer.datasheet.id, is_super_admin: true } }
      {_conn, user} = update_user(conn, "branch_admin1@instedd.org", volunteer, params)

      refute user.datasheet.is_super_admin
    end
  end

  describe "detail" do
    test "an admin can access any users detail", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
    end

    test "a branch admin can access details of colaborators of administrated branches", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
    end

    test "a branch admin can not access details of other admins of administrated branches", %{conn: conn} do
      volunteer = get_user_by_email("branch_admin3@instedd.org")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert_unauthorized(conn)
    end

    test "a branch admin can not access details of colaborators of branches he doesn't administrate", %{conn: conn} do
      volunteer = get_user_by_email("volunteer2@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer))

      assert_unauthorized(conn)
    end
  end

  describe "own profile" do
    test "renders admin's own profile", %{conn: conn} do
      user = get_user_by_email("admin@instedd.org")

      conn = conn
      |> log_in(user)
      |> get(users_path(Registro.Endpoint, :profile))

      response = html_response(conn, 200)

      assert response =~ user.datasheet.first_name
      assert response =~ user.datasheet.last_name
    end

    test "renders volunteer own profile", %{conn: conn} do
      user = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in(user)
      |> get(users_path(Registro.Endpoint, :profile))

      response = html_response(conn, 200)

      assert response =~ user.datasheet.first_name
      assert response =~ user.datasheet.last_name
      assert response =~ String.upcase Datasheet.status_label(user.datasheet.status)
      assert response =~ user.datasheet.branch.name
    end
  end

  describe "CSV download" do
    test "it allows downloading all users' information as CSV", %{conn: conn} do
      conn = conn
      |> log_in("admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :download_csv))

      response = response(conn, 200)

      assert response == """
      Apellido,Nombre,Email,Tipo de documento,Número de documento,Nacionalidad,Fecha de nacimiento,Ocupación,Dirección,Filial,Rol,Estado\r
      Doe,admin,admin@instedd.org,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_admin1,branch_admin1@instedd.org,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_admin2,branch_admin2@instedd.org,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_admin3,branch_admin3@instedd.org,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,,,\r
      Doe,volunteer1,volunteer1@example.com,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,Branch 1,Voluntario,Pendiente\r
      Doe,volunteer2,volunteer2@example.com,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,Branch 2,Voluntario,Pendiente\r
      Doe,volunteer3,volunteer3@example.com,Documento nacional de identidad,1,Argentina,1980-01-01,-,-,Branch 3,Voluntario,Pendiente\r
      """
    end
  end

  def get_user_by_email(email) do
    User.query_with_datasheet |> Repo.get_by!(email: email)
  end

  def update_user(conn, %User{} = current_user, target_user, params) do
    conn = conn
    |> log_in(current_user)
    |> patch(users_path(Registro.Endpoint, :update, target_user.datasheet), params)

    {conn, Repo.get(User.query_with_datasheet, target_user.id)}
  end

  def update_user(conn, current_user_email, target_user, params) do
    update_user(conn, get_user_by_email(current_user_email), target_user, params)
  end
end
