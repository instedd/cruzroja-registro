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

File.stream!("priv/data/branches.csv")
|> Enum.map(fn line -> String.replace(line, "\n", "") end)
|> Enum.each(fn branch_name ->
  Branch.changeset(%Branch{}, %{name: branch_name})
  |> Repo.insert!
end)


User.changeset(%User{}, %{name: "Admin", email: "admin@instedd.org", password: "admin", password_confirmation: "admin", role: "administrator"})
|> Repo.insert!


User.changeset(%User{}, %{name: "Branch Employee", email: "branch@instedd.org", password: "branch", password_confirmation: "branch", role: "branch_employee", branch_id: Repo.get_by!(Branch, name: "Saavedra").id})
|> Repo.insert!
