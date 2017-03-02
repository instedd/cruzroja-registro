defmodule Registro.InvitationControllerTest do
  use Registro.ConnCase

  import Registro.ModelTestHelpers
  import Registro.ControllerTestHelpers

  alias Registro.{Invitation, Datasheet, User}

  setup(context) do
    create_country("Argentina")

    super_admin = create_super_admin("super_admin@instedd.org")
    admin = create_admin("admin@instedd.org")
    reader = create_reader("reader@instedd.org")

    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")

    branch1_admin = create_branch_admin("branch1@instedd.org", branch1)
    branch1_clerk = create_branch_clerk("branch1_clerk@instedd.org", branch1)
    branch1_volunteer = create_volunteer("mary@example.com", branch1.id)

    {:ok, Map.merge(context, %{
                      super_admin: super_admin,
                      admin: admin,
                      reader: reader,
                      branch1: branch1,
                      branch2: branch2,
                      branch1_admin: branch1_admin,
                      branch1_clerk: branch1_clerk,
                      branch1_volunteer: branch1_volunteer,
                    })}
  end

  describe "form rendering" do
    test "renders invitation form with all branches for global admins", %{conn: conn, super_admin: super_admin, admin: admin} do
      Enum.each([super_admin, admin], fn user ->
        conn = conn
        |> log_in(user)
        |> get("/usuarios/alta")

        assert html_response(conn, 200)
        assert branches_names(conn) == ["Branch 1", "Branch 2"]
      end)
    end

    test "doesn't renders invitation form for global readers", %{conn: conn, reader: reader} do
      conn =
        conn
        |> log_in(reader)
        |> get("/usuarios/alta")

      assert_unauthorized(conn)
    end

    test "renders invitation form with administrated branches for branch admin", %{conn: conn, branch1_admin: branch1_admin} do
      conn = conn
      |> log_in(branch1_admin)
      |> get("/usuarios/alta")

      assert html_response(conn, 200)
      assert branches_names(conn) == ["Branch 1"]
    end

    test "renders invitation form with accessible branches for branch clerk", %{conn: conn, branch1_clerk: branch1_clerk} do
      conn = conn
            |> log_in(branch1_clerk)
            |> get("/usuarios/alta")

      assert html_response(conn, 200)
      assert branches_names(conn) == ["Branch 1"]
    end

    test "is not available for non admin users", %{conn: conn, branch1_volunteer: volunteer} do
      conn = conn
      |> log_in(volunteer)
      |> get("/usuarios/alta")

      assert_unauthorized(conn)
    end

    defp branches_names(conn) do
      conn.assigns[:branches] |> Enum.map(fn {name, _id} -> name end)
    end
  end

  describe "sending invitations" do
    test "global admin can send invitations for any branch", %{conn: conn, branch1: branch, admin: admin} do
      params = invitation_params(branch.id)

      conn = conn
      |> log_in(admin)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      verify_invitation(params)
    end

    test "super admin can send invitations for any branch", %{conn: conn, branch1: branch, super_admin: super_admin} do
      params = invitation_params(branch.id)

      conn = conn
      |> log_in(super_admin)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      verify_invitation(params)
    end

    test "global reader can not send invitations", %{conn: conn, branch1: branch, reader: reader} do
      params = invitation_params(branch.id)

      conn = conn
      |> log_in(reader)
      |> post("/usuarios/alta", params)

      assert_unauthorized(conn)
    end

    test "branch admin can send invitations for the same branch", %{conn: conn, branch1: branch, branch1_admin: branch_admin} do
      params = invitation_params(branch.id)

      conn = conn
      |> log_in(branch_admin)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      verify_invitation(params)
    end

    test "branch clerk can send invitations for the same branch", %{conn: conn, branch1: branch, branch1_clerk: branch_clerk} do
      params = invitation_params(branch.id)

      conn = conn
      |> log_in(branch_clerk)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      verify_invitation(params)
    end

    test "branch admin can not send invitations for other branches", %{conn: conn, branch2: branch2, branch1_admin: branch1_admin} do
      params = invitation_params(branch2.id)

      conn = conn
      |> log_in(branch1_admin)
      |> post("/usuarios/alta", params)

      assert_unauthorized(conn)
      assert Invitation.count == 0
    end

    test "branch clerk can not send invitations for other branches", %{conn: conn, branch2: branch2, branch1_clerk: branch1_clerk} do
      params = invitation_params(branch2.id)

      conn = conn
      |> log_in(branch1_clerk)
      |> post("/usuarios/alta", params)

      assert_unauthorized(conn)
      assert Invitation.count == 0
    end

    test "volunteers can not send invitations", %{conn: conn, branch1_volunteer: branch1_volunteer, branch1: branch1} do
      params = invitation_params(branch1.id)

      conn = conn
      |> log_in(branch1_volunteer)
      |> post("/usuarios/alta", params)

      assert_unauthorized(conn)
      assert Invitation.count == 0
    end

    defp invitation_params(branch_id) do
      %{ "invitation" =>
        %{ "email" => "john@example.com",
           "datasheet" => %{
             "first_name" => "John",
             "last_name" => "Doe",
             "legal_id_kind" => "DNI",
             "legal_id" => "1",
             "birth_date" => ~D[1980-01-01],
             "occupation" => "...",
             "address" => "...",
             "phone_number" => "...",
             "country_id" => some_country!.id,
             "role" => "volunteer",
             "branch_id" => "#{branch_id}"
           }
         }
      }
    end

    defp verify_invitation(params) do
      %Invitation{datasheet: datasheet} = Repo.get_by!(Invitation, email: params["invitation"]["email"])
      |> Repo.preload([:datasheet])

      assert datasheet.status == "at_start"
      assert datasheet.role == "volunteer"
      assert datasheet.branch_id == String.to_integer(params["invitation"]["datasheet"]["branch_id"])
    end
  end


  describe "invitation confirmation" do
    test "creates a new user and deletes invitation", %{conn: conn} do
      token = setup_invitation("john@example.com")

      confirmation_params = %{ "token" => token,
                              "user" => %{ "password" => "foobar",
                                            "password_confirmation" => "foobar" }}

      conn
      |> post("/registracion/invitado/confirmar", confirmation_params)
      |> html_response(302)


      verify_invitation_accepted("john@example.com")
    end

    test "does not allow to change email", %{conn: conn} do
      token = setup_invitation("john@example.com")

      confirmation_params = %{ "token" => token,
                               "user" => %{ "email" => "changed@example.com",
                                            "password" => "foobar",
                                            "password_confirmation" => "foobar" }}

      conn
      |> post("/registracion/invitado/confirmar", confirmation_params)
      |> html_response(302)

      verify_invitation_accepted("john@example.com")
    end

    defp setup_invitation(email) do
      token = "thetoken"

      branch = create_branch(name: "Branch")

      datasheet_params = %{ "first_name" => "John",
                            "last_name" => "Doe",
                            "legal_id_kind" => "DNI",
                            "legal_id" => "1",
                            "birth_date" => ~D[1980-01-01],
                            "occupation" => "...",
                            "address" => "...",
                            "phone_number" => "...",
                            "country_id" => some_country!.id,
                            "status" => "at_start",
                            "role" => "volunteer",
                            "branch_id" => branch.id }

      datasheet = Datasheet.changeset(%Datasheet{}, datasheet_params)
      |> Repo.insert!

      invitation_params = %{ "name" => "John",
                             "email" => email,
                             "token" => token }

      Invitation.changeset(%Invitation{}, invitation_params)
      |> Ecto.Changeset.put_assoc(:datasheet, datasheet)
      |> Repo.insert!

      token
    end

    defp verify_invitation_accepted(email) do
      assert Invitation.count == 0

      user = Repo.get_by!(User, email: email)
           |> Repo.preload([:datasheet])

      assert user.datasheet.first_name == "John"
    end
  end

end
