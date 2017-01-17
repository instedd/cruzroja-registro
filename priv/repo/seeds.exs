# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Registro.Repo.insert!(%Registro.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Registro.Repo
alias Registro.Branch
alias Registro.User

defmodule Seed do
  def run do
    File.stream!("priv/data/branches.csv")
    |> Enum.map(&parse_branch_line/1)
    |> Enum.each(fn [branch_name, address, province, president, authorities, phone, cell, email] ->
      Branch.changeset(%Branch{}, %{name: titleize(branch_name), address: titleize(address <> " - " <> province), president: titleize(president), authorities: titleize(authorities), phone_number: phone, cell_phone_number: cell, email: email}) |> Repo.insert!
    end)

    users = [
      %{name: "Admin", email: "admin@instedd.org", password: "admin", password_confirmation: "admin", role: "super_admin"},
      %{name: "Branch Employee", email: "branch@instedd.org", password: "branch", password_confirmation: "branch", role: "branch_admin", branch_id: Repo.get_by!(Branch, name: "Saavedra").id},
    ]

    Enum.map(users, &insert_user/1)
  end

  def parse_branch_line(line) do
    line
    |> String.replace("\n", "")
    |> String.split(",")
  end


  def insert_user(params) do
    User.changeset(%User{}, params) |> Repo.insert!
  end

  def titleize(string) do
    map = String.split(string," ")
    map
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

Seed.run
