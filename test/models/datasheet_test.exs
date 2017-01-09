defmodule Registro.DatasheetTest do
  use Registro.ModelCase

  alias Registro.Branch
  alias Registro.Datasheet

  test "a datasheet can be created without association to a user" do
    cs = Datasheet.changeset(%Datasheet{name: "John"},
      %{role: "super_admin",
        branch_id: nil,
        status: "approved"
      })

    assert cs.valid?
  end

  test "a volunteer cannot have empty branch_id" do
    cs = Datasheet.changeset(%Datasheet{name: "John"},
      %{role: "volunteer",
        branch_id: nil,
        status: "approved"
    })

    assert invalid_fields(cs) == [:branch_id]
  end

  test "a volunteer cannot have empty status" do
    branch = create_branch(name: "Branch")

    cs = Datasheet.changeset(%Datasheet{name: "John"},
      %{role: "volunteer",
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
