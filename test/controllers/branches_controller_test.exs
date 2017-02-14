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

    super_admin = create_super_admin("super_admin@instedd.org")
    admin = create_admin("admin@instedd.org")

    create_branch_admin("branch_admin1@instedd.org", branch1, %{country_id: some_country.id})
    create_branch_admin("branch_admin2@instedd.org", branch1, %{country_id: some_country.id})

    create_branch_clerk("branch_clerk1@instedd.org", branch1, %{country_id: some_country.id})
    create_branch_clerk("branch_clerk2@instedd.org", branch2, %{country_id: some_country.id})

    {:ok, Map.merge(context, %{ super_admin: super_admin,
                                admin: admin,
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

    test "displays all branches to global admin", %{conn: conn, admin: admin} do
      conn = conn
      |> log_in(admin)
      |> get("/filiales")

      assert html_response(conn, 200)
      assert (Enum.count conn.assigns[:branches]) == 2
    end

    test "displays all branches to super admin", %{conn: conn, super_admin: super_admin} do
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
    test "a global admin has edit only access to his branches", %{conn: conn, branch1: branch1} do
      Enum.each(["admin@instedd.org", "super_admin@instedd.org"], fn email ->
        conn = conn
        |> log_in(email)
        |> get(branches_path(conn, :show, branch1))

        assert html_response(conn, 200)
        assert conn.assigns[:abilities] == [:view, :update]
      end)
    end

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

    test "allows to update a branch's contact information", %{conn: conn, branch1: branch} do
      params = %{ admin_emails: "branch_admin1@instedd.org|branch_admin2@instedd.org",
                  clerk_emails: "",
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
  end

  describe "admins management" do
    test "allows to add branch admins", %{conn: conn, branch1: branch} do
      desired_admins = ["branch_admin1@instedd.org",
                        "branch_admin2@instedd.org",
                        "mary@example.com"]

      admins_update(conn, "branch_admin1@instedd.org", branch, desired_admins)
      updated_admins = updated_admins(branch) |> classify

      assert updated_admins == [{:existing, "branch_admin1@instedd.org"},
                                {:existing, "branch_admin2@instedd.org"},
                                {:existing, "mary@example.com"}]
    end

    test "generates audit entries for new admins", %{conn: conn, branch1: branch} do
      desired_admins = ["branch_admin1@instedd.org",
                        "branch_admin2@instedd.org",
                        "mary@example.com"]

      admins_update(conn, "branch_admin1@instedd.org", branch, desired_admins)

      user = Repo.get_by!(User, email: "mary@example.com") |> Repo.preload(:datasheet)

      audit_entries = UserAuditLogEntry.for(user.datasheet, "branch_admin_granted")

      assert Enum.count(audit_entries) == 1
    end

    test "allows to remove other admins", %{conn: conn, branch1: branch} do
      admins_update(conn, "branch_admin1@instedd.org", branch, ["branch_admin1@instedd.org"])
      updated_admins = updated_admins(branch) |> classify

      assert updated_admins == [{:existing, "branch_admin1@instedd.org"}]

      # assert that deleting the association does not delete the user
      Repo.get_by!(Registro.User, email: "branch_admin2@instedd.org")
    end

    test "allows to remove all admins", %{conn: conn, branch1: branch} do
      # test encoding/decoding of empty list
      admins_update(conn, "super_admin@instedd.org", branch, [])

      updated_admins = updated_admins(branch) |> classify
      assert updated_admins == []
    end

    test "generates audit entries for removed admins", %{conn: conn, branch1: branch} do
      admins_update(conn, "branch_admin1@instedd.org", branch, ["branch_admin1@instedd.org"])

      user = Repo.get_by!(User, email: "branch_admin2@instedd.org") |> Repo.preload(:datasheet)

      audit_entries = UserAuditLogEntry.for(user.datasheet, "branch_admin_revoked")

      assert Enum.count(audit_entries) == 1
    end

    test "fails if user is trying to remove himself as branch admin", %{conn: conn, branch1: branch} do
      admins_update(conn, "branch_admin1@instedd.org", branch, ["branch_admin2@instedd.org"])

      updated_admins = updated_admins(branch) |> classify

      assert updated_admins == [{:existing, "branch_admin1@instedd.org"},
                                {:existing, "branch_admin2@instedd.org"}]
    end

    test "sends an invitation to unknown emails", %{conn: conn, branch1: branch} do
      admins_update(conn, "branch_admin1@instedd.org", branch, ["branch_admin1@instedd.org",
                                                                "branch_admin2@instedd.org",
                                                                "unknown@example.com"])
      updated_admins = updated_admins(branch) |> classify

      assert updated_admins == [{:existing, "branch_admin1@instedd.org"},
                                {:existing, "branch_admin2@instedd.org"},
                                {:invited, "unknown@example.com"}]

      invitation = Repo.get_by!(Registro.Invitation, email: "unknown@example.com")
                 |> Repo.preload(:datasheet)

      assert Datasheet.is_admin_of?(invitation.datasheet, branch)
    end
  end

  describe "clerks management" do
    test "allows to add branch clerks", %{conn: conn, branch1: branch} do
      desired_clerks = ["branch_clerk1@instedd.org",
                        "branch_clerk2@instedd.org"]

      clerks_update(conn, "branch_admin1@instedd.org", branch, desired_clerks)
      updated_admins = updated_clerks(branch) |> classify

      assert updated_admins == [{:existing, "branch_clerk1@instedd.org"},
                                {:existing, "branch_clerk2@instedd.org"}]
    end

    test "generates audit entries for new clerks", %{conn: conn, branch1: branch} do
      desired_admins = ["branch_clerk1@instedd.org",
                        "branch_clerk2@instedd.org"]

      clerks_update(conn, "branch_admin1@instedd.org", branch, desired_admins)

      user = Repo.get_by!(User, email: "branch_clerk2@instedd.org") |> Repo.preload(:datasheet)

      audit_entries = UserAuditLogEntry.for(user.datasheet, "branch_clerk_granted")

      assert Enum.count(audit_entries) == 1
    end

    test "an admin can remove clerks", %{conn: conn, branch1: branch} do
      clerks_update(conn, "branch_admin1@instedd.org", branch, [])
      updated_clerks = updated_clerks(branch) |> classify

      assert updated_clerks == []

      # assert that deleting the association does not delete the user
      Repo.get_by!(Registro.User, email: "branch_clerk1@instedd.org")
    end

    test "generated audit entries for removed clerks", %{conn: conn, branch1: branch} do
      clerks_update(conn, "branch_admin1@instedd.org", branch, [])

      user = Repo.get_by!(User, email: "branch_clerk1@instedd.org") |> Repo.preload(:datasheet)

      audit_entries = UserAuditLogEntry.for(user.datasheet, "branch_clerk_revoked")

      assert Enum.count(audit_entries) == 1
    end

    test "sends an invitation to unknown emails", %{conn: conn, branch1: branch} do
      clerks_update(conn, "branch_admin1@instedd.org", branch, ["branch_clerk1@instedd.org",
                                                                "unknown@example.com"])
      updated_clerks = updated_clerks(branch) |> classify

      assert updated_clerks == [{:existing, "branch_clerk1@instedd.org"},
                                {:invited, "unknown@example.com"}]

      invitation = Repo.get_by!(Registro.Invitation, email: "unknown@example.com")
                 |> Repo.preload(:datasheet)

      assert Datasheet.is_clerk_of?(invitation.datasheet, branch)
    end
  end

  describe "creation" do
    test "a global admin can create new branches", %{conn: conn, admin: admin} do
      params = %{ admin_emails: "", clerk_emails: "", branch: %{ name: "NewBranch" }}

      conn
      |> log_in(admin)
      |> post("/filiales", params)

      branch = Repo.one!(from b in Branch,
                         where: b.name == "NewBranch",
                         preload: :admins)

      assert branch.admins == []
    end

    test "a super admin can create new branches", %{conn: conn, super_admin: super_admin} do
      params = %{ admin_emails: "", clerk_emails: "", branch: %{ name: "NewBranch" }}

      conn
      |> log_in(super_admin)
      |> post("/filiales", params)

      branch = Repo.one!(from b in Branch,
                         where: b.name == "NewBranch",
                         preload: :admins)

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

  defp admins_update(conn, user_email, branch, emails) do
    encoded_emails = Enum.join(emails, "|")
    params = %{ branch: %{ }, admin_emails: encoded_emails, clerk_emails: ""}

    conn
    |> log_in(user_email)
    |> patch(branches_path(conn, :update, branch), params)
  end

  defp clerks_update(conn, user_email, branch, emails) do
    branch = Repo.preload(branch, [admins: [:user]])
    admin_emails = branch.admins |> Enum.map(fn d -> d.user.email end)

    params = %{ branch: %{ }, admin_emails: encode_emails(admin_emails), clerk_emails: encode_emails(emails)}

    conn
    |> log_in(user_email)
    |> patch(branches_path(conn, :update, branch), params)
  end

  defp encode_emails(emails) do
    Enum.join(emails, "|")
  end

  defp updated_admins(branch) do
    branch = Repo.get!(Branch, branch.id) |> Repo.preload([admins: [:user, :invitation]])
    branch.admins
  end

  defp updated_clerks(branch) do
    branch = Repo.get!(Branch, branch.id) |> Repo.preload([clerks: [:user, :invitation]])
    branch.clerks
  end

  defp classify(datasheets) do
    clf = fn(datasheet) ->
      case datasheet do
        %Datasheet{ user: %User{ email: email } } ->
          { :existing, email }
        %Datasheet{ invitation: %Invitation{ email: email }} ->
          { :invited, email }
      end
    end

    datasheets |> Enum.map(clf) |> Enum.sort
  end
end
