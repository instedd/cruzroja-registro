defmodule Registro.InvitationsControllerTest do
  use Registro.ConnCase

  import Registro.ControllerTestHelpers

  alias Registro.{Invitation, Datasheet, User}

  describe "sending invitatioins" do
    test "invitation creation with associated datasheet", %{conn: conn} do
      branch = create_branch(name: "Branch")
      admin = create_user(email: "admin@instedd.org", role: "super_admin")

      params = invitation_params(branch.id)

      conn = conn
      |> log_in(admin)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      verify_invitation(params)
    end

    test "branch admin can send invitations for the same branch", %{conn: conn} do
      branch = create_branch(name: "Branch")
      branch_admin = create_user(email: "branch1@instedd.org", role: "branch_admin", branch_id: branch.id)

      params = invitation_params(branch.id)

      conn = conn
      |> log_in(branch_admin)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      verify_invitation(params)
    end

    test "branch admin can not send invitations for other branches", %{conn: conn} do
      branch1 = create_branch(name: "Branch 1")
      branch2 = create_branch(name: "Branch 2")

      branch1_admin = create_user(email: "branch1@instedd.org", role: "branch_admin", branch_id: branch1.id)

      params = invitation_params(branch2.id)

      conn = conn
      |> log_in(branch1_admin)
      |> post("/usuarios/alta", params)

      assert html_response(conn, 302)

      assert Invitation.count == 0
    end

    test "volunteers can not send invitations" do
    end

    defp invitation_params(branch_id) do
      %{ "invitation" =>
        %{ "name" => "John",
           "email" => "john@example.com",
           "datasheet" => %{
             "role" => "volunteer",
             "branch_id" => "#{branch_id}"
           }
         }
      }
    end

    defp verify_invitation(params) do
      %Invitation{datasheet: datasheet} = Repo.get_by!(Invitation, email: params["invitation"]["email"])
      |> Repo.preload([:datasheet])

      assert datasheet.name == params["invitation"]["name"]
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

      datasheet_params = %{ "name" => "John",
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

      assert user.datasheet.name == "John"
    end
  end

end
