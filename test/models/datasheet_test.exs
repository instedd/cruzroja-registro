defmodule Registro.DatasheetTest do
  use Registro.ModelCase

  import Registro.ModelTestHelpers

  alias Registro.Datasheet

  test "a datasheet can be created without association to a user" do
    cs = Datasheet.changeset(%Datasheet{name: "John"},
      %{role: nil,
        branch_id: nil,
        status: nil,
        is_super_admin: true
      })

    assert cs.valid?
  end

  test "a volunteer cannot have empty branch_id" do
    cs = Datasheet.changeset(%Datasheet{name: "John"},
      %{role: "volunteer",
        branch_id: nil,
        status: "approved",
        is_super_admin: false
    })

    assert invalid_fields(cs) == [:branch_id]
  end

  test "role can not have arbitrary values" do
    branch = create_branch(name: "Branch")

    changeset = fn(role) ->
      Datasheet.changeset(%Datasheet{},
        %{name: "John",
          role: role,
          branch_id: branch.id,
          status: "approved",
          is_super_admin: false
      })
    end

    assert changeset.("volunteer").valid?
    assert changeset.("associate").valid?
    refute changeset.("something_else").valid?
  end

  test "a volunteer cannot have empty status" do
    branch = create_branch(name: "Branch")

    cs = Datasheet.changeset(%Datasheet{name: "John"},
      %{role: "volunteer",
        branch_id: branch.id,
        status: nil,
        is_super_admin: false
      })

    assert invalid_fields(cs) == [:status]
  end

  test "a datasheet can be assigned as admin to multiple branches" do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")
    branch3 = create_branch(name: "Branch 3")

    datasheet = create_datasheet(%{"name" => "John", "role" => nil, "branch_id" => nil, "status" => nil})

    datasheet = datasheet
    |> Datasheet.make_admin_changeset([branch1, branch2])
    |> Repo.update!

    assert Enum.count(datasheet.admin_branches) == 2

    assert Datasheet.is_admin_of?(datasheet, branch1)
    assert Datasheet.is_admin_of?(datasheet, branch2)
    refute Datasheet.is_admin_of?(datasheet, branch3)
  end

  def invalid_fields(changeset) do
    changeset.errors
    |> Keyword.keys
    |> Enum.uniq
  end
end
