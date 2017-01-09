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
    |> Enum.each(fn [branch_name, address] ->
      Branch.changeset(%Branch{}, %{name: branch_name, address: address}) |> Repo.insert!
    end)

    users = [
      %{email: "admin@instedd.org",
        password: "admin",
        password_confirmation: "admin",
        datasheet: %{
          name: "Admin",
          role: "super_admin"
        }
       },
      %{email: "branch@instedd.org",
        password: "branch",
        password_confirmation: "branch",
        datasheet: %{
          name: "Branch Employee",
          role: "branch_admin",
          branch_id: Repo.get_by!(Branch, name: "Saavedra").id
        }
      }
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
end

Seed.run
