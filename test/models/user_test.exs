defmodule Registro.UserTest do
  use Registro.ModelCase

  alias Registro.User
  alias Registro.Branch

  test "a volunteer cannot have empty branch_id" do
    cs = User.changeset(%User{name: "John"},
      %{email: "john@example.com",
        role: "volunteer",
        password: "fooo",
        password_confirmation: "fooo",
        branch_id: nil,
        status: "approved"
    })

    assert invalid_fields(cs) == [:branch_id]
  end

  test "a volunteer cannot have empty status" do
    branch = create_branch(name: "Branch")

    cs = User.changeset(%User{name: "John"},
      %{email: "john@example.com",
        role: "volunteer",
        password: "fooo",
        password_confirmation: "fooo",
        branch_id: branch.id,
        status: nil
      })

    assert invalid_fields(cs) == [:status]
  end

  def invalid_fields(changeset) do
    changeset.errors
    |> Keyword.keys
    |> Enum.uniq
  end

  def create_branch(name: name) do
    changeset = Branch.changeset(%Branch{}, %{
          name: name,
          address: "generated"
    })

    Repo.insert! changeset
  end
end
