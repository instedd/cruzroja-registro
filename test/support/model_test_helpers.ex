defmodule Registro.ModelTestHelpers do

  alias Registro.Repo
  alias Registro.{Country, Branch, User, Datasheet}

  def create_country(name) do
    Country.changeset(%Country{}, %{name: name})
    |> Repo.insert!
  end

  def some_country! do
    import Ecto.Query
    Repo.one!(from c in Country, limit: 1)
  end

  def create_volunteer(email, branch_id, params \\ %{}) do
    params = Map.merge(params, %{ role: "volunteer", branch_id: branch_id, status: "at_start" })

    user_changeset(email, params)
    |> Repo.insert!
  end

  def create_branch_clerk(email, branches, params \\ %{})
  def create_branch_clerk(email, branches, params) when is_list(branches) do
    user = Repo.insert! user_changeset(email, params)

    user.datasheet
    |> Datasheet.make_clerk_changeset(branches)
    |> Repo.update!

    user
  end
  def create_branch_clerk(email, branch, params) do
    create_branch_clerk(email, [branch], params)
  end

  def create_branch_admin(email, branches, params \\ %{})
  def create_branch_admin(email, branches, params) when is_list(branches) do
    user = Repo.insert! user_changeset(email, params)

    user.datasheet
    |> Datasheet.make_admin_changeset(branches)
    |> Repo.update!

    user
  end
  def create_branch_admin(email, branch, params) do
    create_branch_admin(email, [branch], params)
  end

  def create_super_admin(email, params \\ %{}) do
    params = Map.merge(params, %{global_grant: "super_admin"})

    user_changeset(email, params)
    |> Repo.insert!
  end

  def create_admin(email, params \\ %{}) do
    params = Map.merge(params, %{global_grant: "admin"})

    user_changeset(email, params)
    |> Repo.insert!
  end

  def create_reader(email, params \\ %{}) do
    params = Map.merge(params, %{global_grant: "reader"})

    user_changeset(email, params)
    |> Repo.insert!
  end

  def create_datasheet(params) do
    Datasheet.changeset(%Datasheet{}, params)
    |> Repo.insert!
  end

  def create_branch(name: name) do
    create_branch(name: name, eligible: true)
  end

  def create_branch(name: name, eligible: eligible) do
    changeset = Branch.creation_changeset(%{ name: name,
                                             address: "generated",
                                             eligible: eligible })
    Repo.insert! changeset
  end

  defp name(email) do
    String.replace(email, ~r/@.*/, "")
  end

  def invalid_fields(changeset) do
    changeset.errors
    |> Keyword.keys
    |> Enum.uniq
  end

  defp user_changeset(email, datasheet_overrides) do
    User.changeset(%User{}, :update, user_params(email, datasheet_overrides))
  end

  defp user_params(email, datasheet_overrides) do
    # innocent hacks for default values... :-)
    # - generate a name based on the email
    # - use the email as legal_id to avoid duplicates. we should
    #   probably have an agent to generate these
    datasheet_overrides = Map.merge(%{first_name: name(email),
                                      legal_id_kind: "CI",
                                      legal_id: email}, datasheet_overrides)

    datasheet_params = datasheet_params(datasheet_overrides)

    %{ email: email,
       password: "generated",
       password_confirmation: "generated",
       datasheet: datasheet_params}
  end

  defp datasheet_params(overrides) do
    country_id = overrides[:country_id] || some_country!.id

    base_params = %{ first_name: "John",
                     last_name: "Doe",
                     legal_id_kind: "DNI",
                     legal_id: "1",
                     birth_date: ~D[1980-01-01],
                     occupation: "-",
                     address: "-",
                     phone_number: "+1222222",
                     country_id: country_id,
                     global_grant: nil }

    Map.merge(base_params, overrides)
  end
end
