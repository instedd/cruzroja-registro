defmodule Registro.ModelTestHelpers do

  alias Registro.Repo
  alias Registro.{Country, Branch, User, Datasheet}

  def create_country(name) do
    Country.changeset(%Country{}, %{ name: name})
    |> Repo.insert!
  end

  def some_country! do
    import Ecto.Query
    Repo.one!(from c in Country, limit: 1)
  end

  def create_user(params = [email: email, role: role]) do
    branch_id = params[:branch_id]

    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated", password_confirmation: "generated",
          datasheet: %{
            name: name(email),
            role: role,
            branch_id: branch_id,
            status: "at_start"
          }})
    Repo.insert! changeset
  end

  def create_volunteer(email, branch_id, params \\ []) do
    country_id = params[:country_id] || some_country!.id

    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated", password_confirmation: "generated",
          datasheet: %{ first_name: name(email),
                        last_name: "Doe",
                        legal_id_kind: "DNI",
                        legal_id_number: "1",
                        birth_date: ~D[1980-01-01],
                        occupation: "-",
                        address: "-",
                        country_id: country_id,
                        role: "volunteer",
                        branch_id: branch_id,
                        status: "at_start" }})

    Repo.insert! changeset
  end

  def create_branch_admin(a,b,c \\ [])
  def create_branch_admin(email, branches, params) when is_list(branches) do
    country_id = params[:country_id] || some_country!.id

    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated", password_confirmation: "generated",
          datasheet: %{ first_name: name(email),
                        last_name: "Doe",
                        legal_id_kind: "DNI",
                        legal_id_number: "1",
                        birth_date: ~D[1980-01-01],
                        occupation: "-",
                        address: "-",
                        country_id: country_id }})

    user = Repo.insert! changeset

    user.datasheet
    |> Datasheet.make_admin_changeset(branches)
    |> Repo.update!

    user
  end
  def create_branch_admin(email, branch, params) do
    create_branch_admin(email, [branch], params)
  end

  def create_super_admin(email, params \\ []) do
    country_id = params[:country_id] || some_country!.id

    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated", password_confirmation: "generated",
          datasheet: %{ first_name: name(email),
                        last_name: "Doe",
                        legal_id_kind: "DNI",
                        legal_id_number: "1",
                        birth_date: ~D[1980-01-01],
                        occupation: "-",
                        address: "-",
                        country_id: country_id,
                        is_super_admin: true }})
    Repo.insert! changeset
  end

  def create_datasheet(params) do
    Datasheet.changeset(%Datasheet{}, params)
    |> Repo.insert!
  end

  def create_branch(name: name) do
    changeset = Branch.changeset(%Branch{}, %{
          name: name,
          address: "generated"
    })
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
end
