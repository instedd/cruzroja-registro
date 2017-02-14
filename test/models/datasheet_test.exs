defmodule Registro.DatasheetTest do
  use Registro.ModelCase

  import Registro.ModelTestHelpers

  alias Registro.Country
  alias Registro.Datasheet

  setup do
    country = Country.changeset(%Country{}, %{ name: "Argentina" })
            |> Repo.insert!

    {:ok, [minimal_params: %{first_name: "John",
                             last_name: "Doe",
                             legal_id_kind: "DNI",
                             legal_id_number: "1",
                             birth_date: ~D[1980-01-01],
                             occupation: "-",
                             address: "-",
                             phone_number: "+1222222",
                             country_id: country.id }]}
  end

  test "a datasheet can be created without association to a user", %{minimal_params: params} do
    cs = Datasheet.changeset(%Datasheet{}, params)

    assert cs.valid?
    assert Ecto.Changeset.get_field(cs, :filled) == true
  end

  test "validates required fields", %{minimal_params: params} do
    Datasheet.required_fields |> Enum.each(fn field ->
      params = Map.delete(params, field)
      cs = Datasheet.changeset(%Datasheet{}, params)
      refute cs.valid?
    end)
  end

  test "allows to create empty sheet for unconfirmed users" do
    cs = Datasheet.new_empty_changeset()

    assert cs.valid?
    assert Ecto.Changeset.get_field(cs, :filled) == false

    Datasheet.required_fields |> Enum.each(fn field ->
      assert Ecto.Changeset.get_field(cs, field) == nil
    end)
  end

  test "a volunteer cannot have empty branch_id", %{minimal_params: params} do
    params = Map.merge(params, %{role: "volunteer",
                                 branch_id: nil,
                                 status: "approved",
                                })

    cs = Datasheet.changeset(%Datasheet{}, params)

    assert invalid_fields(cs) == [:branch_id]
  end

  test "role can not have arbitrary values", %{minimal_params: params} do
    branch = create_branch(name: "Branch")

    changeset = fn(role) ->
      params = Map.merge(params, %{role: role,
                                   branch_id: branch.id,
                                   status: "approved" })

      Datasheet.changeset(%Datasheet{}, params)
    end

    assert changeset.("volunteer").valid?
    assert changeset.("associate").valid?
    refute changeset.("something_else").valid?
  end

  test "global_grant can not have arbitrary values", %{minimal_params: params} do
    changeset = fn(global_grant) ->
      params = Map.merge(params, %{ global_grant: global_grant })

      Datasheet.changeset(%Datasheet{}, params)
    end

    assert changeset.("super_admin").valid?
    assert changeset.("admin").valid?
    refute changeset.("something_else").valid?
  end

  test "a volunteer cannot have empty status", %{minimal_params: params} do
    branch = create_branch(name: "Branch")

    params = Map.merge(params, %{role: "volunteer",
                                 branch_id: branch.id,
                                 status: nil,
                                })

    cs = Datasheet.changeset(%Datasheet{}, params)

    assert invalid_fields(cs) == [:status]
  end

  test "a datasheet can be assigned as admin to multiple branches", %{minimal_params: params} do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")
    branch3 = create_branch(name: "Branch 3")

    datasheet = Map.merge(params, %{role: nil, branch_id: nil, status: nil})
              |> create_datasheet

    datasheet = datasheet
    |> Datasheet.make_admin_changeset([branch1, branch2])
    |> Repo.update!

    assert Enum.count(datasheet.admin_branches) == 2

    assert Datasheet.is_admin_of?(datasheet, branch1)
    assert Datasheet.is_admin_of?(datasheet, branch2)
    refute Datasheet.is_admin_of?(datasheet, branch3)
  end

  test "a super admin can filter by branch", %{minimal_params: params} do
    datasheet = Map.merge(params, %{global_grant: "super_admin"})
    |> create_datasheet

    assert Datasheet.can_filter_by_branch?(datasheet)
  end

  test "a branch admin with one branch cannot filter by branch", %{minimal_params: params} do
    branch = create_branch(name: "Branch 1")

    datasheet = create_datasheet(params)
    |> Datasheet.make_admin_changeset([branch])
    |> Repo.update!

    refute Datasheet.can_filter_by_branch?(datasheet)
  end

  test "a branch admin with multiple branches can filter by branch", %{minimal_params: params} do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")

    datasheet = create_datasheet(params)
    |> Datasheet.make_admin_changeset([branch1, branch2])
    |> Repo.update!

    assert Datasheet.can_filter_by_branch?(datasheet)
  end

  test "a branch clerk with one branch cannot filter by branch", %{minimal_params: params} do
    branch = create_branch(name: "Branch 1")

    datasheet = create_datasheet(params)
              |> Datasheet.make_clerk_changeset([branch])
              |> Repo.update!

    refute Datasheet.can_filter_by_branch?(datasheet)
  end

  test "a branch clerk with multiple branches can filter by branch", %{minimal_params: params} do
    branch1 = create_branch(name: "Branch 1")
    branch2 = create_branch(name: "Branch 2")

    datasheet = create_datasheet(params)
              |> Datasheet.make_clerk_changeset([branch1, branch2])
              |> Repo.update!

    assert Datasheet.can_filter_by_branch?(datasheet)
  end
end
