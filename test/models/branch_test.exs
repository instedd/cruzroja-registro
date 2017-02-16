defmodule Registro.BranchTest do
  use Registro.ModelCase

  import Registro.ModelTestHelpers

  test "branches are created with incremental identifiers" do
    b1 = create_branch(name: "Branch 1")
    b2 = create_branch(name: "Branch 2")
    b3 = create_branch(name: "Branch 3")

    assert b2.identifier == b1.identifier + 1
    assert b3.identifier == b2.identifier + 1
  end
end
