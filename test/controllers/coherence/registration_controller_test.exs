defmodule Registro.RegistrationControllerTest do

  use Registro.ConnCase
  import Registro.ModelTestHelpers

  alias Registro.User

  setup(context) do
    create_country("Argentina")

    branch1 = create_branch(name: "Branch 1", eligible: true)
    branch2 = create_branch(name: "Branch 2", eligible: false)
    branch3 = create_branch(name: "Branch 3", eligible: true)

    {:ok, Map.merge(context, %{ branch1: branch1,
                                branch2: branch2,
                                branch3: branch3 })}
  end

  test "form only lists eligible branches", %{conn: conn} do
    conn = get(conn, registration_path(conn, :new))

    branch_names = conn.assigns[:branches] |> Enum.map(fn {name, _id} -> name end)

    assert branch_names == ["Branch 1", "Branch 3"]
  end

  test "creates user and datasheet on form submit", %{conn: conn, branch1: branch1} do
    post(conn, registration_path(conn, :create, registration_params(branch1)))

    user = Repo.get_by!(User, email: "u1@example.com") |> Repo.preload(:datasheet)

    assert user.datasheet.first_name == "John"
    assert user.datasheet.last_name == "Doe"

    assert user.datasheet.role == "volunteer"
    assert user.datasheet.branch_id == branch1.id
    assert user.datasheet.status == "at_start"
  end

  test "fails if a non-eligible branch is sent", %{conn: conn, branch2: branch2} do
    post(conn, registration_path(conn, :create, registration_params(branch2)))

    user = Repo.get_by(User, email: "u1@example.com") |> Repo.preload(:datasheet)

    assert is_nil(user)
  end

  def registration_params(branch) do
    %{ registration: %{
        email: "u1@example.com",
        password: "fooo",
        password_confirmation: "fooo",

        datasheet: %{
          first_name: "John",
          last_name: "Doe",
          legal_id_kind: "DNI",
          legal_id_number: "1",
          birth_date: "1980-01-01",
          occupation: "-",
          address: "-",
          phone_number: "+1222222",
          country_id: some_country!.id,
          global_grant: nil,

          role: "volunteer",
          branch_id: branch.id }}}
  end
end
