defmodule Registro.PaginationTest do
  use Registro.ModelCase
  import Registro.ModelTestHelpers

  alias Registro.Pagination
  alias Registro.Branch

  setup(context) do
    create_branch(name: "Branch 1")
    create_branch(name: "Branch 2")
    create_branch(name: "Branch 3")

    {:ok, context}
  end

  test "allows to retrieve items with pagination" do
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
    total_count = Registro.Repo.count Branch

    assert Pagination.page_count(total_count, page_size: 1) == 3
    assert Pagination.page_count(total_count, page_size: 2) == 2
    assert Pagination.page_count(total_count, page_size: 3) == 1
  end
end
