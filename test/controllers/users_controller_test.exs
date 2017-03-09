defmodule Registro.UsersControllerTest do
  use Registro.ConnCase
  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.{User, Datasheet, Branch, Invitation}

  setup(context) do
    country = create_country("Argentina")

    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")
    branch3 = create_branch(name: "Branch 3")

    create_super_admin("super_admin@instedd.org", %{legal_id: "1"})
    create_admin("admin@instedd.org", %{legal_id: "2"})
    create_reader("reader@instedd.org", %{legal_id: "3"})

    create_branch_admin("branch_admin1@instedd.org", [branch1, branch3], %{legal_id: "4"})
    create_branch_admin("branch_admin2@instedd.org", branch2, %{legal_id: "5"})
    create_branch_admin("branch_admin3@instedd.org", branch3, %{legal_id: "6"})

    create_branch_clerk("branch_clerk1@instedd.org", [branch1, branch3], %{legal_id: "7"})

    volunteer1 = create_volunteer("volunteer1@example.com", branch1.id, %{legal_id: "8"})
    volunteer2 = create_volunteer("volunteer2@example.com", branch2.id, %{legal_id: "9"})
    volunteer3 = create_volunteer("volunteer3@example.com", branch3.id, %{legal_id: "10"})

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

    test "users with global access can see all users", %{conn: conn} do
      Enum.each(["super_admin@instedd.org", "admin@instedd.org", "reader@instedd.org"], fn login_email ->
        conn =
          conn
          |> log_in(login_email)
          |> get("/usuarios")

        assert html_response(conn, 200)
        assert Enum.count(conn.assigns[:datasheets]) == Repo.count(User)
      end)
    end

    test "users with global access can filter by all branches", %{conn: conn} do
      Enum.each(["super_admin@instedd.org", "admin@instedd.org", "reader@instedd.org"], fn login_email ->
        conn =
          conn
          |> log_in(login_email)
          |> get("/usuarios")

        assert Enum.count(conn.assigns[:branches]) == Repo.count(Branch)
      end)
    end

    test "a branch admin can filter by his accessible branches", %{conn: conn} do
      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/usuarios")

      assert visible_branches(conn) == ["Branch 1", "Branch 3"]
    end

    test "a branch clerk can filter by his accessible branches", %{conn: conn} do
      conn = conn
           |> log_in("branch_clerk1@instedd.org")
           |> get("/usuarios")

      assert visible_branches(conn) == ["Branch 1", "Branch 3"]
    end

    test "branch admin can only see colaborators of his administrated branches", %{conn: conn} do
      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/usuarios")

      assert visible_datasheets(conn) == ["volunteer1@example.com", "volunteer3@example.com"]
    end

    test "branch clerk can only see colaborators of his administrated branches", %{conn: conn} do
      conn = conn
           |> log_in("branch_clerk1@instedd.org")
           |> get("/usuarios")

      assert visible_datasheets(conn) == ["volunteer1@example.com", "volunteer3@example.com"]
    end

    test "a user that is admin and clerk of different branches can see users from both", %{conn: conn} do
      user = get_user_by_email("branch_clerk1@instedd.org")
      other_branch = Repo.get_by!(Branch, name: "Branch 2")

      user.datasheet
      |> Datasheet.make_admin_changeset([other_branch])
      |> Repo.update!

      conn = conn
           |> log_in(user)
           |> get("/usuarios")

      assert visible_datasheets(conn) == ["volunteer1@example.com", "volunteer2@example.com", "volunteer3@example.com"]
    end

    defp visible_datasheets(conn) do
      assert html_response(conn, 200)

      Enum.map(conn.assigns[:datasheets], &(&1.user.email))
      |> Enum.sort
    end

    defp visible_branches(conn) do
      assert html_response(conn, 200)

      Enum.map(conn.assigns[:branches], &(&1.name)) |> Enum.sort
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
        legal_id: "1234567890",
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

      params = %{datasheet: %{ first_name: "This cannot be changed", global_grant: "super_admin" }}

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
        legal_id: "1234567890",
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
    test "a global admin can update a user's branch", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{ branch_name: "Branch 2",
                  selected_role: "paying_associate",
                  datasheet: %{ id: volunteer.datasheet.id } }

      {_conn, volunteer} = update_user(conn, "admin@instedd.org", volunteer, params)

      assert volunteer.datasheet.role == "associate"
      assert volunteer.datasheet.branch.name == "Branch 2"
    end

    test "a super admin can update a user's branch", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{ branch_name: "Branch 2",
                  selected_role: "non_paying_associate",
                  datasheet: %{ id: volunteer.datasheet.id } }

      {_conn, volunteer} = update_user(conn, "super_admin@instedd.org", volunteer, params)

      assert volunteer.datasheet.role == "associate"
      assert volunteer.datasheet.branch.name == "Branch 2"
    end

    test "a global reader can not update a user's branch", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{ branch_name: "Branch 2",
                  selected_role: "non_paying_associate",
                  datasheet: %{ id: volunteer.datasheet.id } }

      {conn, updated_volunteer} = update_user(conn, "reader@instedd.org", volunteer, params)

      assert_unauthorized(conn)
      assert volunteer == updated_volunteer
    end

    test "a branch admin cannot update a user's branch", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      {"volunteer", "Branch 1"} = {volunteer.datasheet.role, volunteer.datasheet.branch.name}

      params = %{ branch_name: "Branch 2",
                  selected_role: "non_paying_associate",
                  datasheet: %{ id: volunteer.datasheet.id } }

      {_conn, updated_volunteer} = update_user(conn, "branch_admin1@instedd.org", volunteer, params)

      assert volunteer == updated_volunteer
    end

    test "a branch admin can change role of colaborations of the same branch", %{conn: conn} do
      u1 = get_user_by_email("branch_admin1@instedd.org")
      u2 = get_user_by_email("volunteer1@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ :selected_role => "paying_associate", :datasheet => %{ }}

      {_conn, u2} = update_user(conn, u1, u2, params)

      assert u2.datasheet.role == "associate"
      assert u2.datasheet.is_paying_associate == true
    end

    test "a branch admin can't change role of colaborations of other branches", %{conn: conn} do
      u1 = get_user_by_email("branch_admin1@instedd.org")
      u2 = get_user_by_email("volunteer2@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ :selected_role => "paying_associate", :datasheet => %{ }}

      {conn, _u2} = update_user(conn, u1, u2, params)

      assert_unauthorized(conn)
    end

    test "a branch clerk can't update users of the same branch", %{conn: conn} do
      u1 = get_user_by_email("branch_clerk1@instedd.org")
      u2 = get_user_by_email("volunteer1@example.com")

      assert u2.datasheet.role == "volunteer"

      params = %{ :selected_role => "paying_associate",
                  :datasheet => %{} }

      {conn, updated_u2} = update_user(conn, u1, u2, params)

      assert_unauthorized(conn)
      assert u2 == updated_u2
    end
  end

  describe "status changes" do
    test "a global admin is allowed to approve any volunteer", %{conn: conn} do
      {_conn, user} = update_state(conn, "admin@instedd.org", "volunteer1@example.com", :approve, "volunteer")
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
    end

    test "a super admin is allowed to approve any volunteer", %{conn: conn} do
      {_conn, user} = update_state(conn, "super_admin@instedd.org", "volunteer1@example.com", :approve, "volunteer")
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
    end

    test "a super admin is allowed to change a registration_date upon approval", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      params = %{
        email: volunteer.email,
        flow_action: "approve", selected_role: "volunteer",
        datasheet: %{id: volunteer.datasheet.id, registration_date: "2010-01-01" }}

      {_conn, user} = update_user(conn, "super_admin@instedd.org", volunteer, params)

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
      assert user.datasheet.is_paying_associate == nil
      assert user.datasheet.registration_date == ~D[2010-01-01]
    end

    test "a super admin is allowed to change a volunteer to paying associate upon approval", %{conn: conn} do
      {_conn, user} = update_state(conn, "super_admin@instedd.org", "volunteer1@example.com", :approve, "paying_associate")
      assert user.datasheet.role == "associate"
      assert user.datasheet.status == "approved"
      assert user.datasheet.is_paying_associate == true
    end

    test "a super admin is allowed to change a volunteer to non-associate upon approval", %{conn: conn} do
      {_conn, user} = update_state(conn, "super_admin@instedd.org", "volunteer1@example.com", :approve, "non_paying_associate")
      assert user.datasheet.role == "associate"
      assert user.datasheet.status == "approved"
      assert user.datasheet.is_paying_associate == false
    end

    test "a global reader is not allowed to approve any volunteer", %{conn: conn} do
      {conn, user} = update_state(conn, "reader@instedd.org", "volunteer1@example.com", :approve, "volunteer")
      assert_unauthorized(conn)
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "at_start"
    end

    test "a global admin is allowed to reject any volunteer", %{conn: conn} do
      {_conn, user} = update_state(conn, "admin@instedd.org", "volunteer1@example.com", :reject, "volunteer")
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "rejected"
    end

    test "a super admin is allowed to reject any volunteer", %{conn: conn} do
      {_conn, user} = update_state(conn, "super_admin@instedd.org", "volunteer1@example.com", :reject, "volunteer")
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "rejected"
    end

    test "a branch admin is allowed to change the status of volunteers of his administrated branches", %{conn: conn} do
      {_conn, user} = update_state(conn, "branch_admin1@instedd.org", "volunteer1@example.com", :approve, "volunteer")
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
    end

    test "a branch admin is not allowed to change the status of volunteers of branches he doesn't adminstrate", %{conn: conn} do
      {conn, user} = update_state(conn, "branch_admin2@instedd.org", "volunteer1@example.com", :approve, "volunteer")

      assert_unauthorized(conn)
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "at_start"
    end

    test "a volunteer is not allowed to change his status", %{conn: conn} do
      {conn, user} = update_state(conn, "volunteer1@example.com", "volunteer1@example.com", :approve, "volunteer")

      assert_unauthorized(conn)
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "at_start"
    end

    test "a global admin is allowed to approve requests from volunteers to become associates", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      volunteer =
        volunteer
        |> User.changeset(:update, %{ datasheet: %{ id: volunteer.datasheet.id,
                                                  status: "associate_requested",
                                                  is_paying_associate: false } })
                                                  |> Repo.update!

        {_conn, user} = update_state(conn, "admin@instedd.org", volunteer, :approve, "non_paying_associate")

        assert user.datasheet.role == "associate"
        assert user.datasheet.is_paying_associate == false
        assert user.datasheet.status == "approved"
    end

    test "a global admin is allowed to reject requests from volunteers to become associates", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      volunteer =
        volunteer
        |> User.changeset(:update, %{ datasheet: %{ id: volunteer.datasheet.id,
                                                    status: "associate_requested",
                                                    is_paying_associate: false } })
        |> Repo.update!

      {_conn, user} = update_state(conn, "admin@instedd.org", volunteer, :reject, "non_paying_associate")

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.is_paying_associate == nil
      assert user.datasheet.status == "approved"
    end

    test "a super admin is allowed to approve requests from volunteers to become associates", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      volunteer =
        volunteer
        |> User.changeset(:update, %{ datasheet: %{ id: volunteer.datasheet.id,
                                                  status: "associate_requested",
                                                  is_paying_associate: false } })
                                                  |> Repo.update!

        {_conn, user} = update_state(conn, "super_admin@instedd.org", volunteer, :approve, "non_paying_associate")

        assert user.datasheet.role == "associate"
        assert user.datasheet.is_paying_associate == false
        assert user.datasheet.status == "approved"
    end

    test "a super admin is allowed to change associate kind uppon approval", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      volunteer =
        volunteer
        |> User.changeset(:update, %{ datasheet: %{ id: volunteer.datasheet.id,
                                                  status: "associate_requested",
                                                  is_paying_associate: false } })
        |> Repo.update!

      {_conn, user} = update_state(conn, "super_admin@instedd.org", volunteer, :approve, "paying_associate")

      assert user.datasheet.role == "associate"
      assert user.datasheet.is_paying_associate == true
      assert user.datasheet.status == "approved"
    end

    test "a global reader is not allowed to approve requests from volunteers to become associates", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      volunteer =
        volunteer
        |> User.changeset(:update, %{ datasheet: %{ id: volunteer.datasheet.id,
                                                    status: "associate_requested",
                                                    is_paying_associate: false } })
        |> Repo.update!

      {conn, user} = update_state(conn, "reader@instedd.org", volunteer, :approve, "non_paying_associate")

      assert_unauthorized(conn)

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.is_paying_associate == false
      assert user.datasheet.status == "associate_requested"
    end

    test "registration_date is set automatically if not set before approval", %{conn: conn} do
      user = get_user_by_email("volunteer1@example.com")

      assert is_nil(user.datasheet.registration_date)

      # the view sends empty string when date is not selected
      params = %{
        email: user.email,
        flow_action: "approve", selected_role: "volunteer",
        datasheet: %{id: user.datasheet.id, registration_date: "" }}

      {_conn, updated_user} = update_user(conn, "admin@instedd.org", user, params)

      refute is_nil(updated_user.datasheet.registration_date)
    end

    test "registration_date is not changed if it was set before approval", %{conn: conn} do
      user = get_user_by_email("volunteer1@example.com")

      user.datasheet
      |> Datasheet.changeset(%{registration_date: ~D[1980-01-01]})
      |> Repo.update!

      {_conn, updated_user} = update_state(conn, "admin@instedd.org", user, :approve, "volunteer")

      assert updated_user.datasheet.registration_date == ~D[1980-01-01]
    end

    def update_state(conn, current_user_email, %User{} = volunteer, action, selected_role) do
      params = %{
          email: volunteer.email,
          flow_action: (to_string action),
          selected_role: selected_role,
          datasheet: %{
            id: volunteer.datasheet.id,
          }}

      update_user(conn, current_user_email, volunteer, params)
    end

    def update_state(conn, current_user_email, target_user_email, action, selected_role) do
      volunteer = get_user_by_email(target_user_email)
      update_state(conn, current_user_email, volunteer, action, selected_role)
    end
  end

  describe "volunteer transition to associate" do
    test "an approved volunteer with less than a year can ask to become paying associate", %{conn: conn, some_branch: branch} do
      {conn, user} =
        create_approved_volunteer(branch, less_than_a_year_ago)
        |> request_volunteer_update(conn)

      assert redirected_to(conn) == users_path(Registro.Endpoint, :profile)
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "associate_requested"
      assert user.datasheet.is_paying_associate == true
    end

    test "an approved volunteer with a year or more can ask to become non-paying associate", %{conn: conn, some_branch: branch} do
      {conn, user} =
        create_approved_volunteer(branch, a_year_ago)
        |> request_volunteer_update(conn)

      assert redirected_to(conn) == users_path(Registro.Endpoint, :profile)
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "associate_requested"
      assert user.datasheet.is_paying_associate == false
    end

    test "an audit entry is created when the user requests to become associate", %{conn: conn, some_branch: branch} do
      {_conn, user} =
        create_approved_volunteer(branch, less_than_a_year_ago)
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

    def create_approved_volunteer(branch, registration_date) do
      user = create_volunteer("approved_volunteer@example.com", branch.id)

      user
      |> Ecto.Changeset.change
      |> Ecto.Changeset.put_assoc(:datasheet, %{ id: user.datasheet.id, status: "approved", registration_date: registration_date })
      |> Repo.update!
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
          selected_role: "volunteer",
          datasheet: %{ id: user.datasheet.id, branch_id: branch2.id }
        }

      {_conn, user} = update_user(conn, "super_admin@instedd.org", user, params)

      assert user.datasheet.branch_id == branch2.id
      assert user.datasheet.role == "volunteer"
      assert user.datasheet.status == "approved"
    end
  end

  describe "granting super_admin permissions" do
    test "a super_admin can grant global permissions to other users", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      params = %{selected_role: "volunteer",
                 datasheet: %{ id: volunteer.datasheet.id, global_grant: "super_admin" }}

      {_conn, user} = update_user(conn, "super_admin@instedd.org", volunteer, params)

      assert Datasheet.is_super_admin?(user.datasheet)
    end

    test "a regular global admin can not grant global permissions to other users", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      params = %{selected_role: "volunteer",
                 datasheet: %{ id: volunteer.datasheet.id, global_grant: "super_admin" }}

      {conn, user} = update_user(conn, "admin@instedd.org", volunteer, params)

      assert_unauthorized(conn)
      refute Datasheet.is_super_admin?(user.datasheet)
    end

    test "a global reader can not grant global permissions to other users", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      params = %{selected_role: "volunteer",
                 datasheet: %{ id: volunteer.datasheet.id, global_grant: "super_admin" }}

      {conn, user} = update_user(conn, "reader@instedd.org", volunteer, params)

      assert_unauthorized(conn)
      refute Datasheet.is_super_admin?(user.datasheet)
    end

    test "a branch admin cannot grant global permission", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      params = %{ selected_role: "volunteer", datasheet: %{ id: volunteer.datasheet.id, global_grant: "super_admin" } }

      {_conn, user} = update_user(conn, "branch_admin1@instedd.org", volunteer, params)

      refute Datasheet.is_super_admin?(user.datasheet)
    end

    test "a super_admin can revoke super_admin permissions to other users", %{conn: conn} do
      other_admin = create_super_admin("admin2@instedd.org")

      params = %{selected_role: nil,
                 datasheet: %{ id: other_admin.datasheet.id, global_grant: nil}}

      {_conn, other_admin} = update_user(conn, "super_admin@instedd.org", other_admin, params)

      refute Datasheet.is_super_admin?(other_admin.datasheet)
    end

    test "a super_admin cannot revoke his own super_admin permissions", %{conn: conn} do
      admin = get_user_by_email("super_admin@instedd.org")

      {_conn, admin} = update_user(conn, admin, admin, datasheet: %{ id: admin.datasheet.id,
                                                                     global_grant: nil })

      assert Datasheet.is_super_admin?(admin.datasheet)
    end
  end

  describe "detail" do
    test "a global admin can access and edit any user's detail", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view, :update]
    end

    test "a global reader can access any user's detail", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("reader@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view]
    end

    test "a branch admin can access and edit details of colaborators of administrated branches", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view, :update]
    end

    test "a global reader can edit profiles of users of a branch he administrates", %{conn: conn} do
      reader = get_user_by_email("reader@instedd.org")
      volunteer = get_user_by_email("volunteer1@example.com")

      reader.datasheet
      |> Datasheet.make_admin_changeset([volunteer.datasheet.branch])
      |> Repo.update!

      conn = conn
      |> log_in("reader@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view, :update]
    end

    test "a branch clerk can access details of colaborators of administrated branches", %{conn: conn} do
      volunteer = get_user_by_email("volunteer1@example.com")

      conn = conn
      |> log_in("branch_clerk1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view]
    end

    test "a branch admin can not access details of other admins of administrated branches", %{conn: conn} do
      volunteer = get_user_by_email("branch_admin3@instedd.org")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert_unauthorized(conn)
    end

    test "a branch admin can not access details of colaborators of branches he doesn't administrate", %{conn: conn} do
      volunteer = get_user_by_email("volunteer2@example.com")

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get(users_path(Registro.Endpoint, :show, volunteer.datasheet))

      assert_unauthorized(conn)
    end
  end

  describe "own profile" do
    test "renders admin's own profile", %{conn: conn} do
      user = get_user_by_email("super_admin@instedd.org")

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
      |> log_in("super_admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :download_csv))

      response = response(conn, 200)

      assert response == """
      Apellido,Nombre,Email,Tipo de documento,Número de documento,Nacionalidad,Fecha de nacimiento,Ocupación,Dirección,Filial,Rol,Estado\r
      Doe,admin,admin@instedd.org,Cédula de Identidad,2,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_admin1,branch_admin1@instedd.org,Cédula de Identidad,4,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_admin2,branch_admin2@instedd.org,Cédula de Identidad,5,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_admin3,branch_admin3@instedd.org,Cédula de Identidad,6,Argentina,1980-01-01,-,-,,,\r
      Doe,branch_clerk1,branch_clerk1@instedd.org,Cédula de Identidad,7,Argentina,1980-01-01,-,-,,,\r
      Doe,reader,reader@instedd.org,Cédula de Identidad,3,Argentina,1980-01-01,-,-,,,\r
      Doe,super_admin,super_admin@instedd.org,Cédula de Identidad,1,Argentina,1980-01-01,-,-,,,\r
      Doe,volunteer1,volunteer1@example.com,Cédula de Identidad,8,Argentina,1980-01-01,-,-,Branch 1,Voluntario,Pendiente\r
      Doe,volunteer2,volunteer2@example.com,Cédula de Identidad,9,Argentina,1980-01-01,-,-,Branch 2,Voluntario,Pendiente\r
      Doe,volunteer3,volunteer3@example.com,Cédula de Identidad,10,Argentina,1980-01-01,-,-,Branch 3,Voluntario,Pendiente\r
      """
    end

    # regression test for https://github.com/instedd/cruzroja-registro/issues/59
    test "non-filled datasheets with associated users are ignored", %{conn: conn} do
      datasheet = Datasheet.new_empty_changeset |> Repo.insert!
      invite = %Invitation{ email: "foo@example.com", datasheet_id: datasheet.id } |> Repo.preload(:datasheet)

      User.changeset(:create_from_invitation, invite, %{ "password" => "1234", "password_confiramtion" => "1234" })
      |> Repo.insert!

      conn = conn
      |> log_in("super_admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :download_csv))

      response = response(conn, 200)

      assert csv_entry_count(response) == (Repo.count(Datasheet) - 1)
    end

    test "filled datasheets with no associated user are included", %{conn: conn, some_country: country} do
      datasheet = create_datasheet(%{first_name: "John",
                                     last_name: "Dow",
                                     legal_id_kind: "DNI",
                                     legal_id: "1",
                                     birth_date: ~D[1980-01-01],
                                     occupation: "-",
                                     address: "-",
                                     phone_number: "+1222222",
                                     country_id: country.id,
                                     filled: true })

      %Invitation{ email: "datasheet_invitation_email@example.com", datasheet_id: datasheet.id } |> Repo.preload(:datasheet)
      |> Repo.insert!

      conn = conn
      |> log_in("super_admin@instedd.org")
      |> get(users_path(Registro.Endpoint, :download_csv))

      response = response(conn, 200)

      matches = response
              |> String.split("\n")
              |> Enum.filter(&(String.contains?(&1, "datasheet_invitation_email@example.com")))
              |> Enum.count

      assert matches == 1
    end

    defp csv_entry_count(response) do
      (response
      |> String.split("\n")
      |> Enum.filter(&(&1 != "")) # trailing newline
      |> Enum.count) - 1
    end
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
