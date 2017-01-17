defmodule Registro.UserTest do
  use Registro.ModelCase

  import Registro.ModelTestHelpers

  alias Registro.User

  @valid_user_attrs %{email: "john@example.com", password: "fooo", password_confirmation: "fooo"}

  test "a user can be created with a datasheet" do
    params = Map.put(@valid_user_attrs, :datasheet, %{
      name: "John",
      role: nil,
      branch_id: nil,
      status: nil,
      is_super_admin: true
    })

    changeset = User.changeset(:create_with_datasheet, params)

    assert changeset.valid?

    %User{ datasheet: datasheet } = Registro.Repo.insert!(changeset)

    assert datasheet.name == "John"
    assert datasheet.role == nil
    assert datasheet.branch_id == nil
    assert datasheet.status == nil
    assert datasheet.is_super_admin
  end

  test "a user cannot be created with an invalid datasheet" do
    params = Map.put(@valid_user_attrs, :datasheet, %{
          name: nil,
          role: nil,
          branch_id: nil,
          status: nil,
          is_super_admin: true
    })

    refute User.changeset(:create_with_datasheet, params).valid?
  end

  test "cannot mark as colaborator of a branch without setting role" do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")

    user = create_branch_admin(email: "john@example.com", branch: branch1)

    update_params = %{datasheet: %{
                         id: user.datasheet.id,
                         role: nil,
                         branch_id: branch2.id
                      }}

    cs = User.changeset(user, :update, update_params)

    refute cs.valid?
  end
end
