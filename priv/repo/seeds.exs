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

Registro.User.changeset(%Registro.User{}, %{name: "Admin", email: "admin@instedd.org", password: "admin", password_confirmation: "admin"})
|> Registro.Repo.insert!
