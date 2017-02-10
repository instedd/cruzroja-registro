defmodule Registro.BranchesControllerTest do
  use Registro.ConnCase

  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.{
    Branch,
    User,
    Invitation,
    Datasheet,
    UserAuditLogEntry
  }

  setup(context) do
    some_country = create_country("Argentina")

    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")

    volunteer = create_volunteer("mary@example.com", branch1.id)

    super_admin = create_super_admin("admin@instedd.org")

    create_branch_admin("branch_admin1@instedd.org", branch1, %{country_id: some_country.id})
    create_branch_admin("branch_admin2@instedd.org", branch1, %{country_id: some_country.id})

    create_branch_clerk("branch_clerk1@instedd.org", branch1, %{country_id: some_country.id})

    {:ok, Map.merge(context, %{ super_admin: super_admin,
                                branch1: branch1,
                                branch2: branch2,
                                volunteer: volunteer,
                              })}
  end

  describe "listing" do
    test "verifies that user is logged in", %{conn: conn} do
      conn = get conn, "/filiales"
      assert redirected_to(conn) == "/"
    end

    test "does not allow non-admin users", %{conn: conn} do
      conn = conn
      |> log_in("mary@example.com")
      |> get("/filiales")

      assert_unauthorized(conn)
    end

    test "displays all branches to super_admin user", %{conn: conn, super_admin: super_admin} do
      conn = conn
      |> log_in(super_admin)
      |> get("/filiales")

      assert html_response(conn, 200)
      assert (Enum.count conn.assigns[:branches]) == 2
    end

    test "branch admin can only see his administrated branches", %{conn: conn} do
      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/filiales")

      assert html_response(conn, 200)

      branch_names = conn.assigns[:branches]
      |> Enum.map(&(&1.name))

      assert branch_names == ["Branch 1"]
    end

    test "branch clerk can only see his administrated branches", %{conn: conn} do
      conn = conn
      |> log_in("branch_clerk1@instedd.org")
      |> get("/filiales")

      assert html_response(conn, 200)

      branch_names = conn.assigns[:branches]
      |> Enum.map(&(&1.name))

      assert branch_names == ["Branch 1"]
    end
  end

  describe "detail" do
    test "a branch admin has edit only access to his branches", %{conn: conn, branch1: branch1} do
      conn = conn
           |> log_in("branch_admin1@instedd.org")
           |> get(branches_path(conn, :show, branch1))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view, :update]
    end

    test "a branch admin cannot access a branch he doesn't administrate", %{conn: conn, branch2: branch2} do
      conn = conn
           |> log_in("branch_admin1@instedd.org")
           |> get(branches_path(conn, :show, branch2))

      assert_unauthorized(conn)
    end

    test "a branch clerk has read only access to his branches", %{conn: conn, branch1: branch1} do
      conn = conn
           |> log_in("branch_clerk1@instedd.org")
           |> get(branches_path(conn, :show, branch1))

      assert html_response(conn, 200)
      assert conn.assigns[:abilities] == [:view]
    end

    test "a branch clerk cannot other non accessible branches", %{conn: conn, branch2: branch2} do
      conn = conn
           |> log_in("branch_clerk1@instedd.org")
           |> get(branches_path(conn, :show, branch2))

      assert_unauthorized(conn)
    end

    test "a volunteer cannot access a branch's detail", %{conn: conn, branch1: branch1, volunteer: volunteer} do
      conn = conn
           |> log_in(volunteer)
           |> get(branches_path(conn, :show, branch1))

      assert_unauthorized(conn)
    end
  end

  describe "update" do
    test "branch clerk cannot update his branch's details", %{conn: conn, branch1: branch} do
      params = %{ admin_emails: "branch_admin1@instedd.org",
                  branch: %{
                    name: "Updated name",
                    address: "Updated address" }}
      conn = conn
           |> log_in("branch_clerk1@instedd.org")
           |> patch(branches_path(conn, :update, branch), params)

      assert_unauthorized(conn)
    end

    test "allows to update a branch's name and address", %{conn: conn, branch1: branch} do
      params = %{ admin_emails: "branch_admin1@instedd.org|branch_admin2@instedd.org",
                  branch: %{
                    name: "Updated name",
                    address: "Updated address" }}

      conn
      |> log_in("branch_admin1@instedd.org")
      |> patch(branches_path(conn, :update, branch), params)

      branch = Repo.get!(Branch, branch.id)

      assert branch.name == "Updated name"
      assert branch.address == "Updated address"
    end

    test "allows to add branch admins", %{conn: conn} do
      desired_admins = ["branch_admin1@instedd.org",
                        "branch_admin2@instedd.org",
                        "mary@example.com"]

      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", desired_admins)

      assert updated_admins == [{:added, "branch_admin1@instedd.org"},
                                {:added, "branch_admin2@instedd.org"},
                                {:added, "mary@example.com"}]
    end

    test "generated audit entries for new admins", %{conn: conn} do
      desired_admins = ["branch_admin1@instedd.org",
                        "branch_admin2@instedd.org",
                        "mary@example.com"]

      {_conn, _updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", desired_admins)

      user = Repo.get_by!(User, email: "mary@example.com") |> Repo.preload(:datasheet)

      audit_entries = UserAuditLogEntry.for(user.datasheet, "branch_admin_granted")

      assert Enum.count(audit_entries) == 1
    end

    test "allows to remove other admins", %{conn: conn} do
      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin1@instedd.org"])

      assert updated_admins == [{:added, "branch_admin1@instedd.org"}]

      # assert that deleting the association does not delete the user
      Repo.get_by!(Registro.User, email: "branch_admin2@instedd.org")
    end

    test "allows to remove all admins", %{conn: conn} do
      # test encoding/decoding of empty list
      {_conn, updated_admins} = admins_update(conn, "admin@instedd.org", "Branch 1", [])

      assert updated_admins == []
    end

    test "generated audit entries for removed admins", %{conn: conn} do
      {_conn, _updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin1@instedd.org"])

      user = Repo.get_by!(User, email: "branch_admin2@instedd.org") |> Repo.preload(:datasheet)

      audit_entries = UserAuditLogEntry.for(user.datasheet, "branch_admin_revoked")

      assert Enum.count(audit_entries) == 1
    end

    test "fails if user is trying to remove himself as branch admin", %{conn: conn} do
      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin2@instedd.org"])

      assert updated_admins == [{:added, "branch_admin1@instedd.org"},
                                {:added, "branch_admin2@instedd.org"}]
    end

    test "sends an invitation to unknown emails", %{conn: conn, branch1: branch} do
      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin1@instedd.org",
                                                                                              "branch_admin2@instedd.org",
                                                                                              "unknown@example.com"])

      assert updated_admins == [{:added, "branch_admin1@instedd.org"},
                                {:added, "branch_admin2@instedd.org"},
                                {:invited, "unknown@example.com"}]

      invitation = Repo.get_by!(Registro.Invitation, email: "unknown@example.com")
                 |> Repo.preload(:datasheet)

      assert Datasheet.is_admin_of?(invitation.datasheet, branch)
    end

    defp admins_update(conn, user_email, branch_name, emails) do
      branch = Repo.get_by!(Branch, name: branch_name)

      encoded_emails = Enum.join(emails, "|")
      params = %{ branch: %{ }, admin_emails: encoded_emails}

      conn
      |> log_in(user_email)
      |> patch(branches_path(conn, :update, branch), params)

      branch = Repo.get!(Branch, branch.id)
             |> Repo.preload([admins: [:user, :invitation]])

      updated_admins = Enum.map(branch.admins, fn(datasheet) ->
        case datasheet do
          %Datasheet{ user: %User{ email: email } } ->
            { :added, email }
          %Datasheet{ invitation: %Invitation{ email: email }} ->
            { :invited, email }
        end
      end)

      {conn, Enum.sort(updated_admins)}
    end
  end

  describe "creation" do
    test "a super_admin can create new branches", %{conn: conn, super_admin: super_admin} do
      params = %{ admin_emails: "", branch: %{ name: "NewBranch" }}

      conn
      |> log_in(super_admin)
      |> post("/filiales", params)

      branch = (from b in Branch, where: b.name == "NewBranch", preload: :admins)
             |> Repo.one

      assert branch.admins == []
    end

    test "branch admins are not allowed to create branches", %{conn: conn} do
      params = %{ admin_emails: "", branch: %{ name: "NewBranch" }}

      conn = conn
           |> log_in("branch_admin1@instedd.org")
           |> post("/filiales", params)

      branch = (from b in Branch, where: b.name == "NewBranch", preload: :admins)
             |> Repo.one

      assert_unauthorized(conn)

      assert branch == nil
    end
  end
end
