defmodule Registro.InvitationsControllerTest do
  use Registro.ConnCase

  import Registro.ControllerTestHelpers

  alias Registro.{Invitation, Datasheet}

  test "invitation creation with associated datasheet", %{conn: conn} do
    branch = create_branch(name: "Branch")
    admin = create_user(email: "admin@instedd.org", role: "super_admin")

    params = %{ "invitation" =>
                %{ "name" => "John",
                   "email" => "john@example.com",
                   "datasheet" => %{
                     "role" => "volunteer",
                     "branch_id" => branch.id
                   }
                 }
              }

    conn = conn
         |> log_in(admin)
         |> post("/usuarios/alta", params)

    assert html_response(conn, 302)

    %Invitation{datasheet: datasheet} = Repo.get_by!(Invitation, email: "john@example.com")
                                      |> Repo.preload([:datasheet])

    assert datasheet.name == "John"
    assert datasheet.status == "at_start"
    assert datasheet.role == "volunteer"
    assert datasheet.branch_id == branch.id
  end

  test "invitation confirmation", %{conn: conn} do
    branch = create_branch(name: "Branch")

    datasheet_params = %{ "name" => "John",
                          "status" => "at_start",
                          "role" => "volunteer",
                          "branch_id" => branch.id }

    datasheet = Datasheet.changeset(%Datasheet{}, datasheet_params)
              |> Repo.insert!


    invitation_params = %{ "name" => "John",
                           "email" => "john@example.com",
                           "token" => "thetoken" }

    invitation = Invitation.changeset(%Invitation{}, invitation_params)
                |> Ecto.Changeset.put_assoc(:datasheet, datasheet)
                |> Repo.insert!

    confirmation_params = %{ "token" => invitation.token,
                             "user" => %{ "password" => "foobar",
                                          "password_confirmation" => "foobar" }}

    conn
    |> post("/registracion/invitado/confirmar", confirmation_params)
    |> html_response(302)

    assert Invitation.count == 0

    %Datasheet{ user: user } = Repo.preload datasheet, [:user]

    assert user.email == "john@example.com"
    assert user.datasheet_id == datasheet.id
  end

end
