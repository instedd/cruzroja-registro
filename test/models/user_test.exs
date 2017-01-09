defmodule Registro.UserTest do
  use Registro.ModelCase

  alias Registro.User

  @valid_user_attrs %{email: "john@example.com", password: "fooo", password_confirmation: "fooo"}

  test "a user can be created without a datasheet" do
    assert User.changeset(%User{}, @valid_user_attrs).valid?
  end

  test "a user can be created with a datasheet" do
    params = Map.put(@valid_user_attrs, :datasheet, %{
      name: "John",
      role: "super_admin",
      branch_id: nil,
      status: "approved"
    })

    changeset = User.changeset(%User{}, params)

    assert changeset.valid?

    %User{ datasheet: datasheet } = Registro.Repo.insert!(changeset)

    assert datasheet.name == "John"
    assert datasheet.role == "super_admin"
    assert datasheet.branch_id == nil
    assert datasheet.status == "approved"
  end

  test "a user cannot be created with an invalid datasheet" do
    params = Map.put(@valid_user_attrs, :datasheet, %{
          name: nil,
          role: "super_admin",
          branch_id: nil,
          status: "approved"
    })

    refute User.changeset(%User{}, params).valid?
  end
end
