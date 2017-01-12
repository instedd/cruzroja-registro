defmodule Registro.ModelTestHelpers do

  alias Registro.Repo
  alias Registro.{Branch, User, Datasheet}

  def create_user(email: email, role: role) do
    create_user(email: email, role: role, branch_id: nil)
  end

  def create_user(email: email, role: role, branch_id: branch_id) do
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

  def create_branch_admin(email: email, branch: branch),
    do: create_branch_admin(email: email, branches: [branch])

  def create_branch_admin(email: email, branches: branches) do
    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated", password_confirmation: "generated",
          datasheet: %{
            name: name(email),
            role: nil, branch_id: nil, status: nil}})

    user = Repo.insert! changeset

    user.datasheet
    |> Repo.preload(:admin_branches)
    |> Ecto.Changeset.change
    |> Ecto.Changeset.put_assoc(:admin_branches, branches)
    |> Repo.update!

    user
  end

  def create_super_admin(email: email) do
    changeset = User.changeset(:create_with_datasheet, %{
          email: email,
          password: "generated", password_confirmation: "generated",
          datasheet: %{
            name: name(email),
            role: nil,
            branch_id: nil,
            status: nil,
            is_super_admin: true
          }})

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
end
