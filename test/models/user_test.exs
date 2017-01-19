defmodule Registro.UserTest do
  use Registro.ModelCase

  import Registro.ModelTestHelpers

  alias Registro.Country
  alias Registro.User

  setup do
    country = Country.changeset(%Country{}, %{ name: "Argentina" })
    |> Repo.insert!

    {:ok, [some_country: country,
           minimal_params: %{email: "john@example.com",
                             password: "fooo",
                             password_confirmation: "fooo",
                             datasheet: %{ first_name: "John",
                                           last_name: "Doe",
                                           legal_id_kind: "DNI",
                                           legal_id_number: "1",
                                           birth_date: ~D[1980-01-01],
                                           occupation: "-",
                                           address: "-",
                                           country_id: country.id }}]}
  end

  test "a user can be created with a datasheet", %{minimal_params: params} do
    changeset = User.changeset(:create_with_datasheet, params)

    assert changeset.valid?

    %User{ datasheet: datasheet } = Registro.Repo.insert!(changeset)

    assert datasheet.first_name == "John"
  end

  test "a user cannot be created with an invalid datasheet", %{minimal_params: params} do
    params = update_in(params, [:datasheet], fn(dp) ->
              Map.merge(dp, %{first_name: nil})
            end)

    cs = User.changeset(:create_with_datasheet, params)

    refute cs.valid?
  end

  test "cannot mark as colaborator of a branch without setting role", %{some_country: country} do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")

    user = create_branch_admin("john@example.com", branch1, country_id: country.id)

    update_params = %{datasheet: %{
                         id: user.datasheet.id,
                         role: nil,
                         branch_id: branch2.id
                      }}

    cs = User.changeset(user, :update, update_params)

    refute cs.valid?
  end
end
