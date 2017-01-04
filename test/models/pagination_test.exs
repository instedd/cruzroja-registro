defmodule Registro.PaginationTest do
  use Registro.ModelCase

  alias Registro.Pagination
  alias Registro.Branch

  test "allows to retrieve items with pagination" do
    save_test_branches

    page1_names = Pagination.query(Branch, page_number: 1, page_size: 2)
                |> Registro.Repo.all
                |> Enum.map(fn %Branch{name: name} -> name end)

    page2_names = Pagination.query(Branch, page_number: 2, page_size: 2)
                |> Registro.Repo.all
                |> Enum.map(fn %Branch{name: name} -> name end)

    assert page1_names == ["Branch 1", "Branch 2"]
    assert page2_names == ["Branch 3"]
  end

  test "returns the number of pages" do
    save_test_branches
    total_count = Registro.Repo.aggregate Branch, :count, :id

    assert Pagination.page_count(total_count, page_size: 1) == 3
    assert Pagination.page_count(total_count, page_size: 2) == 2
    assert Pagination.page_count(total_count, page_size: 3) == 1
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
