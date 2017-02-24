defmodule Registro.RegistrationControllerTest do

  use Registro.ConnCase
  import Registro.ModelTestHelpers

  alias Registro.User

  setup(context) do
    create_country("Argentina")

    branch1 = create_branch(name: "Branch 1", eligible: true, province: "La Pampa")
    branch2 = create_branch(name: "Branch 2", eligible: false, province: "La Pampa")
    branch3 = create_branch(name: "Branch 3", eligible: true, province: "La Pampa")

    {:ok, Map.merge(context, %{ branch1: branch1,
                                branch2: branch2,
                                branch3: branch3 })}
  end

  test "form only lists eligible branches", %{conn: conn} do
    conn = get(conn, registration_path(conn, :new))

    branch_names = conn.assigns[:branches]["La Pampa"] |> Enum.map(fn {name, _id} -> name end)

    assert branch_names == ["Branch 3", "Branch 1"]
  end

  describe "creation" do
    test "allows new volunteers", %{conn: conn, branch1: branch1} do
      params = registration_params(branch1, %{ colaboration_kind: "new_colaboration",
                                               new_colaboration_role: "volunteer" })

      post(conn, registration_path(conn, :create, params))

      user = get_user_by_email("u1@example.com")

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.branch_id == branch1.id
      assert user.datasheet.status == "at_start"
      assert user.datasheet.is_paying_associate == nil
    end

    test "allows new associates", %{conn: conn, branch1: branch1} do
      params = registration_params(branch1, %{ colaboration_kind: "new_colaboration",
                                               new_colaboration_role: "associate" })

      post(conn, registration_path(conn, :create, params))

      user = get_user_by_email("u1@example.com")

      assert user.datasheet.role == "associate"
      assert user.datasheet.branch_id == branch1.id
      assert user.datasheet.status == "at_start"
      assert user.datasheet.is_paying_associate == true
    end

    test "allows pre-existing volunteers", %{conn: conn, branch1: branch1} do
      params = registration_params(branch1, %{ colaboration_kind: "current_volunteer",
                                               current_volunteer_desired_role: "volunteer",
                                               current_volunteer_registration_date: "2010-01-01" })

      post(conn, registration_path(conn, :create, params))

      user = get_user_by_email("u1@example.com")

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.branch_id == branch1.id
      assert user.datasheet.status == "at_start"
      assert user.datasheet.registration_date == ~D[2010-01-01]
      assert user.datasheet.is_paying_associate == nil
    end

    test "pre-existing volunteers with 1 year or more that want to become associates don't need to pay", %{conn: conn, branch1: branch1} do
      date = a_year_ago

      params = registration_params(branch1, %{ colaboration_kind: "current_volunteer",
                                               current_volunteer_desired_role: "associate",
                                               current_volunteer_registration_date: Ecto.Date.to_iso8601(date)})

      post(conn, registration_path(conn, :create, params))

      user = get_user_by_email("u1@example.com")

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.branch_id == branch1.id
      assert user.datasheet.status == "associate_requested"
      assert Ecto.Date.cast!(user.datasheet.registration_date) == date
      assert user.datasheet.is_paying_associate == false
    end

    test "pre-existing volunteers with less than 1 year that want to become associates need to pay", %{conn: conn, branch1: branch1} do
      date = less_than_a_year_ago

      params = registration_params(branch1, %{ colaboration_kind: "current_volunteer",
                                               current_volunteer_desired_role: "associate",
                                               current_volunteer_registration_date: Ecto.Date.to_iso8601(date)})

      post(conn, registration_path(conn, :create, params))

      user = get_user_by_email("u1@example.com")

      assert user.datasheet.role == "volunteer"
      assert user.datasheet.branch_id == branch1.id
      assert user.datasheet.status == "associate_requested"
      assert Ecto.Date.cast!(user.datasheet.registration_date) == date
      assert user.datasheet.is_paying_associate == true
    end

    test "allows pre-existing associates", %{conn: conn, branch1: branch1} do
      params = registration_params(branch1, %{ colaboration_kind: "current_associate" })

      post(conn, registration_path(conn, :create, params))

      user = get_user_by_email("u1@example.com")

      # in this case, the admin will set whether the user should pay or not upon approval,
      # after checking against the preexisting associate's records.

      assert user.datasheet.role == "associate"
      assert user.datasheet.branch_id == branch1.id
      assert user.datasheet.status == "at_start"
      assert is_nil(user.datasheet.registration_date)
    end
  end

  test "fails if a non-eligible branch is sent", %{conn: conn, branch2: branch2} do
    params = registration_params(branch2, %{ colaboration_kind: "new_colaboration",
                                             new_colaboration_role: "volunteer"})

    post(conn, registration_path(conn, :create, params))

    user = Repo.get_by(User, email: "u1@example.com") |> Repo.preload(:datasheet)

    assert is_nil(user)
  end

  def registration_params(branch, base_params) do
    Map.merge(base_params,
      %{registration: %{
          email: "u1@example.com",
          password: "fooo",
          password_confirmation: "fooo",


          datasheet: %{
            first_name: "John",
            last_name: "Doe",
            legal_id_kind: "DNI",
            legal_id: "1",
            birth_date: "1980-01-01",
            occupation: "-",
            address: "-",
            phone_number: "+1222222",
            country_id: some_country!.id,
            global_grant: nil,
            branch_id: branch.id,
          }}})
  end
end
