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
                             legal_id: "1",
                             birth_date: ~D[1980-01-01],
                             occupation: "-",
                             address_street: "-",
                             address_number: 1,
                             address_city: "-",
                             address_province: "Buenos Aires",
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
                                 status: "at_start",
                                })

    cs = Datasheet.changeset(%Datasheet{}, params)

    assert invalid_fields(cs) == [:branch_id]
  end

  test "registration_date must be set for approved volunteers", %{minimal_params: params} do
    branch = create_branch(name: "Branch")

    params = Map.merge(params, %{role: "volunteer",
                                 branch_id: branch.id,
                                 status: "approved",
                                })

    cs = Datasheet.changeset(%Datasheet{}, params)

    assert invalid_fields(cs) == [:registration_date]
  end

  test "role can not have arbitrary values", %{minimal_params: params} do
    branch = create_branch(name: "Branch")

    params = Map.merge(params, %{role: "invalid_role",
                                 branch_id: branch.id,
                                 status: "at_start" })

    changeset = Datasheet.changeset(%Datasheet{}, params)

    refute changeset.valid?
    assert invalid_fields(changeset) == [:role]
  end

  test "global_grant can not have arbitrary values", %{minimal_params: params} do
    changeset = fn(global_grant) ->
      params = Map.merge(params, %{ global_grant: global_grant })

      Datasheet.changeset(%Datasheet{}, params)
    end

    assert changeset.("super_admin").valid?
    assert changeset.("admin").valid?
    assert changeset.("reader").valid?
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

  test "super_admin can filter by branch", %{minimal_params: params} do
    datasheet =
      Map.merge(params, %{global_grant: "super_admin"})
      |> create_datasheet

    assert Datasheet.can_filter_by_branch?(datasheet)
  end

  test "admin can filter by branch", %{minimal_params: params} do
    datasheet =
      Map.merge(params, %{global_grant: "admin"})
      |> create_datasheet

    assert Datasheet.can_filter_by_branch?(datasheet)
  end

  test "global reader can filter by branch", %{minimal_params: params} do
    datasheet =
      Map.merge(params, %{global_grant: "reader"})
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

  describe "paying associates" do
    test "is_paying_associate must not be NULL for associates", %{minimal_params: params} do
      branch = create_branch(name: "Branch")

      params = Map.merge(params, %{ branch_id: branch.id,
                                    role: "associate",
                                    status: "approved",
                                    is_paying_associate: nil })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      refute changeset.valid?
      assert invalid_fields(changeset) == [:is_paying_associate]
    end

    test "is_paying_associate must not be NULL for volunteers requesting to become associate", %{minimal_params: params} do
      branch = create_branch(name: "Branch")

      params = Map.merge(params, %{ branch_id: branch.id,
                                    role: "volunteer",
                                    status: "associate_requested",
                                    registration_date: ~D[2010-01-01],
                                    is_paying_associate: nil })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      refute changeset.valid?
      assert invalid_fields(changeset) == [:is_paying_associate]
    end

    test "is_paying_associate must be NULL for other volunteers", %{minimal_params: params} do
      branch = create_branch(name: "Branch")

      params = Map.merge(params, %{ branch_id: branch.id,
                                    role: "volunteer",
                                    status: "at_start",
                                    is_paying_associate: false })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      refute changeset.valid?
      assert invalid_fields(changeset) == [:is_paying_associate]
    end


    test "associates can have the flag set", %{minimal_params: params} do
      branch = create_branch(name: "Branch")

      params = Map.merge(params, %{ branch_id: branch.id,
                                    role: "associate",
                                    status: "approved",
                                    is_paying_associate: false })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      assert changeset.valid?
    end

  end

  describe "legal id" do
    test "legal_id_kind can not contain arbitrary values", %{minimal_params: params} do
      params = Map.merge(params, %{ legal_id_kind: "SOMETHING_ELSE",
                                    legal_id: "12345678" })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      refute changeset.valid?
      assert invalid_fields(changeset) == [:legal_id_kind]
    end

    test "legal id must be unique", %{minimal_params: params} do
      params = Map.merge(params, %{ legal_id_kind: "DNI",
                                    legal_id: "12345678" })


      changeset = Datasheet.changeset(%Datasheet{}, params)

      assert changeset.valid?

      {:ok, _datasheet} = Repo.insert(changeset)
      {:error, insert_changeset} = Repo.insert(changeset)

      refute insert_changeset.valid?
      assert invalid_fields(insert_changeset) == [:legal_id]
    end

    test "legal_id can be duplicated if legal_id_kind doesn't match", %{minimal_params: params} do
      params = Map.merge(params, %{ legal_id_kind: "DNI",
                                    legal_id: "12345678" })

      {:ok, _datasheet1} = Datasheet.changeset(%Datasheet{}, params) |> Repo.insert

      params = Map.merge(params, %{ legal_id_kind: "CI" })

      {:ok, _datasheet2} = Datasheet.changeset(%Datasheet{}, params) |> Repo.insert
    end

    test "whitespace and dots are removed from legal_id if kind is DNI", %{minimal_params: params} do
      params = Map.merge(params, %{ legal_id_kind: "DNI",
                                    legal_id: "12.345 678" })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      assert changeset.valid?
      assert get_field(changeset, :legal_id) == "12345678"
    end

    test "legal_id must be numeric if kind is DNI", %{minimal_params: params} do
      params = Map.merge(params, %{ legal_id_kind: "DNI",
                                    legal_id: "1234N" })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      refute changeset.valid?
      assert invalid_fields(changeset) == [:legal_id]
    end

    test "legal_id doesn't need to be a number if kind is not DNI", %{minimal_params: params} do
      params = Map.merge(params, %{ legal_id_kind: "CI",
                                    legal_id: "1234N" })

      changeset = Datasheet.changeset(%Datasheet{}, params)

      assert changeset.valid?
    end
  end

  describe "branch-scoped identifier generation" do
    setup :setup_colaboration

    test "does not generate an identifier for datasheets without branch" do
      datasheet = Datasheet.new_empty_changeset |> Repo.insert!

      assert is_nil(datasheet.branch_identifier)
    end

    test "generates a new identifier when registering as colaborator of a branch", %{ds_with_colaboration_params: params} do
      datasheet =
        %Datasheet{}
        |> Datasheet.registration_changeset(params)
        |> Repo.insert!

      assert !is_nil(datasheet.branch_identifier)
    end

    test "doesn't change identifier if update params don't include branch_id", %{ds_with_colaboration_params: params} do
      datasheet =
        %Datasheet{}
        |> Datasheet.registration_changeset(params)
        |> Repo.insert!

      updated_datasheet =
        datasheet
        |> Datasheet.changeset(%{first_name: "Another name"})
        |> Repo.update!

      assert datasheet.branch_identifier == updated_datasheet.branch_identifier
    end

    test "doesn't change identifier if update params include same branch_id", %{ds_with_colaboration_params: params} do
      datasheet =
        %Datasheet{}
        |> Datasheet.registration_changeset(params)
        |> Repo.insert!

      updated_datasheet =
        datasheet
        |> Datasheet.changeset(%{branch_id: params[:branch_id]})
        |> Repo.update!

      assert datasheet.branch_identifier == updated_datasheet.branch_identifier
    end

    test "generates a new identifier when branch changes", ctx do
      %{ ds_with_colaboration_params: params,
         branch1: branch1,
         branch2: branch2 } = ctx

      # to allow verifying that a new identifier was generated once the branch changes
      ensure_different_seq_nums!(branch1, branch2)

      datasheet =
        %Datasheet{}
        |> Datasheet.registration_changeset(params)
        |> Repo.insert!

      updated_datasheet =
        datasheet
        |> Datasheet.changeset(%{branch_id: branch2.id})
        |> Repo.update!

      assert !is_nil(updated_datasheet.branch_identifier)
      assert datasheet.branch_identifier != updated_datasheet.branch_identifier
    end

    def setup_colaboration(%{minimal_params: minimal_params} = context) do
      branch1 = create_branch(name: "Branch 1")
      branch2 = create_branch(name: "Branch 2")

      datasheet_params = Map.merge(minimal_params, %{ branch_id: branch1.id,
                                                      role: "volunteer",
                                                      status: "at_start" })

      {:ok, Map.merge(context, %{ branch1: branch1,
                                  branch2: branch2,
                                  ds_with_colaboration_params: datasheet_params })}
    end

    def ensure_different_seq_nums!(branch1, branch2) do
      {:ok, seq1} = PgSql.next_datasheet_seq_num(branch1.id)
      {:ok, seq2} = PgSql.next_datasheet_seq_num(branch2.id)

      if seq1 == seq2 do
        PgSql.next_datasheet_seq_num(branch1.id)
      end
    end
  end
end
