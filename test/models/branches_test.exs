defmodule Registro.BranchesTest do
  use Registro.ModelCase

  alias Registro.Branch

  test "allows to retrieve all branches without pagination" do
    save_test_branches

    assert (Branch.all |> Enum.count) == 3
  end

  test "allows to retrieve branches with pagination" do
    save_test_branches

    page1_names = Branch.all(page_number: 1, page_size: 2)
                |> Enum.map(fn %Branch{name: name} -> name end)

    page2_names = Branch.all(page_number: 2, page_size: 2)
                |> Enum.map(fn %Branch{name: name} -> name end)

    assert page1_names == ["Branch 1", "Branch 2"]
    assert page2_names == ["Branch 3"]
  end

  test "returns the number of pages" do
    save_test_branches

    assert Branch.page_count(page_size: 1) == 3
    assert Branch.page_count(page_size: 2) == 2
    assert Branch.page_count(page_size: 3) == 1
  end

  def save_test_branches do
    branches_params = [
      %{ name: "Branch 1", address: "Foo" },
      %{ name: "Branch 2", address: "Bar" },
      %{ name: "Branch 3", address: "Baz" },
    ]

    Enum.map(branches_params, fn params ->
      Branch.changeset(%Branch{}, params) |> Repo.insert!
    end)
  end
end
