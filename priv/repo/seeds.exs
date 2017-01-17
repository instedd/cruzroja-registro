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

alias Registro.{
  Branch,
  Datasheet,
  Repo,
  User
}

defmodule Seed do
  def run do
    insert_branches

    branch1 = Repo.get_by!(Branch, name: "Saavedra")
    branch2 = Repo.get_by!(Branch, name: "Mercedes")

    branch1_admin_email = "amartinez@cruzroja.org.ar"
    branch2_admin_email = "rmarquez@cruzroja.org.ar"

    users = [
      %{email: "admin@instedd.org",
        password: "admin",
        password_confirmation: "admin",
        datasheet: %{
          name: "Admin",
          is_super_admin: true
        }
       },
      %{email: branch1_admin_email,
        password: "amartinez",
        password_confirmation: "amartinez",
        datasheet: %{ name: "Agustín Martínez" }
      },
      %{email: "jperez@gmail.com",
        password: "jperez",
        password_confirmation: "jperez",
        datasheet: %{
          name: "Juan Pérez",
          role: "volunteer",
          status: "approved",
          branch_id: branch1.id
        }
      },
      %{email: branch2_admin_email,
        password: "rmarquez",
        password_confirmation: "rmarquez",
        datasheet: %{ name: "Raquel Márquez" }
      },
      %{email: "msanchez@hotmail.com",
        password: "msanchez",
        password_confirmation: "msanchez",
        datasheet: %{
          name: "Maria Sánchez",
          role: "volunteer",
          status: "approved",
          branch_id: branch2.id
        }
      }
    ]

    Enum.map(users, &insert_user/1)

    mark_as_branch_admin(branch1_admin_email, branch1)
    mark_as_branch_admin(branch2_admin_email, branch2)
  end

  def insert_branches do
    File.stream!("priv/data/branches.csv")
    |> Enum.map(&parse_branch_line/1)
    |> Enum.each(fn [branch_name, address] ->
      Branch.changeset(%Branch{}, %{name: branch_name, address: address}) |> Repo.insert!
    end)
  end

  def parse_branch_line(line) do
    line
    |> String.replace("\n", "")
    |> String.split(",")
  end

  def insert_user(params) do
    User.changeset(:create_with_datasheet, params) |> Repo.insert!
  end

  def mark_as_branch_admin(email, branch) do
    import Ecto.Query

    user = User
         |> preload(:datasheet)
         |> Repo.get_by!(email: email)

    user.datasheet
    |> Datasheet.make_admin_changeset([branch])
    |> Repo.update!
  end
end

Seed.run
