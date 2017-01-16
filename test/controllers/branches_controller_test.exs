defmodule Registro.BranchesControllerTest do
  use Registro.ConnCase

  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.Branch

  describe "listing" do
    test "verifies that user is logged in", %{conn: conn} do
      conn = get conn, "/filiales"
      assert redirected_to(conn) == "/"
    end

    test "does not allow non-admin users", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("mary@example.com")
      |> get("/filiales")

      assert_unauthorized(conn)
    end

    test "displays all branches to super_admin user", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("admin@instedd.org")
      |> get("/filiales")

      assert html_response(conn, 200)
      assert (Enum.count conn.assigns[:branches]) == 2
    end

    test "branch admin can only see his administrated branches", %{conn: conn} do
      setup_db

      conn = conn
      |> log_in("branch_admin1@instedd.org")
      |> get("/filiales")

      assert html_response(conn, 200)

      branch_names = conn.assigns[:branches]
      |> Enum.map(&(&1.name))

      assert branch_names == ["Branch 1"]
    end
  end

  test "a branch admin cannot access a branch he doesn't administrate", %{conn: conn} do
    setup_db

    branch2 = Repo.get_by!(Branch, name: "Branch 2")

    conn = conn
         |> log_in("branch_admin1@instedd.org")
         |> get(branches_path(conn, :show, branch2))

    assert_unauthorized(conn)
  end

  describe "update" do
    test "allows to update a branch's name and address", %{conn: conn} do
      setup_db

      branch = Repo.get_by!(Branch, name: "Branch 1")

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
      setup_db

      desired_admins = ["branch_admin1@instedd.org",
                        "branch_admin2@instedd.org",
                        "mary@example.com"]

      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", desired_admins)

      assert updated_admins == desired_admins
    end

    test "allows to remove other admins", %{conn: conn} do
      setup_db

      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin1@instedd.org"])

      assert updated_admins == ["branch_admin1@instedd.org"]

      # assert that deleting the association does not delete the user
      Repo.get_by!(Registro.User, email: "branch_admin2@instedd.org")
    end

    test "fails if user is trying to remove himself as branch admin", %{conn: conn} do
      setup_db

      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin2@instedd.org"])

      assert updated_admins == ["branch_admin1@instedd.org", "branch_admin2@instedd.org"]
    end

    test "fails if an invalid admin email is provided", %{conn: conn} do
      setup_db

      {_conn, updated_admins} = admins_update(conn, "branch_admin1@instedd.org", "Branch 1", ["branch_admin1@instedd.org",
                                                                                              "branch_admin2@instedd.org",
                                                                                              "unknown@example.com"])

      assert updated_admins == ["branch_admin1@instedd.org", "branch_admin2@instedd.org"]
    end

    defp admins_update(conn, user_email, branch_name, emails) do
      branch = Repo.get_by!(Branch, name: branch_name)

      encoded_emails = Enum.join(emails, "|")
      params = %{ branch: %{ }, admin_emails: encoded_emails}

      conn
      |> log_in(user_email)
      |> patch(branches_path(conn, :update, branch), params)

      branch = Repo.get!(Branch, branch.id)
             |> Repo.preload([admins: :user])

      updated_admins = Enum.map(branch.admins, &(&1.user.email)) |> Enum.sort
      {conn, updated_admins}
    end
  end

  def setup_db do
    branch1 = create_branch(name: "Branch 1")
    _branch2 = create_branch(name: "Branch 2")

    create_user(email: "mary@example.com", role: "volunteer", branch_id: branch1.id)

    create_super_admin(email: "admin@instedd.org")

    create_branch_admin(email: "branch_admin1@instedd.org", branch: branch1)
    create_branch_admin(email: "branch_admin2@instedd.org", branch: branch1)
  end

end
