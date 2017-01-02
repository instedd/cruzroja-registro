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
File.stream!("priv/data/branches.csv")
|> Enum.map(fn line -> String.replace(line, "\n", "") end)
|> Enum.each(fn branch_name ->
  Registro.Branch.changeset(%Registro.Branch{}, %{name: branch_name})
  |> Registro.Repo.insert!
end)


Registro.User.changeset(%Registro.User{}, %{name: "Admin", email: "admin@instedd.org", password: "admin", password_confirmation: "admin", role: "administrator"})
|> Registro.Repo.insert!


Registro.User.changeset(%Registro.User{}, %{name: "Branch Employee", email: "branch@instedd.org", password: "branch", password_confirmation: "branch", role: "branch_employee"})
|> Registro.Repo.insert!
