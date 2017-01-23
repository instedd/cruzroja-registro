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
  Country,
  Datasheet,
  Repo,
  User
}

defmodule Seed do
  def run do
    insert_branches
    insert_countries

    argentina = Repo.get_by!(Country, name: "Argentina")

    branch1 = Repo.get_by!(Branch, name: "Saavedra")
    branch2 = Repo.get_by!(Branch, name: "Clorinda")

    users = [
      %{email: "admin@instedd.org",
        password: "admin",
        password_confirmation: "admin",
        datasheet: %{
          first_name: "Admin",
          last_name: "-",
          legal_id_kind: "DNI",
          legal_id_number: "11111111",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "Administrador de Cruz Roja",
          address: "-",
          phone_number: "+54 11111111",
          is_super_admin: true
        }
       },
      %{email: "amartinez@cruzroja.org.ar",
        password: "amartinez",
        password_confirmation: "amartinez",
        datasheet: %{
          first_name: "Agustín",
          last_name: "Martínez",
          legal_id_kind: "DNI",
          legal_id_number: "11111111",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "-",
          address: "-",
          phone_number: "+54 11111111",
        }
      },
      %{email: "jperez@gmail.com",
        password: "jperez",
        password_confirmation: "jperez",
        datasheet: %{
          first_name: "Juan",
          last_name: "Pérez",
          legal_id_kind: "DNI",
          legal_id_number: "11111111",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "-",
          address: "-",
          phone_number: "+54 11111111",
          role: "volunteer",
          status: "approved",
          branch_id: branch1.id
        }
      },
      %{email: "rmarquez@cruzroja.org.ar",
        password: "rmarquez",
        password_confirmation: "rmarquez",
        datasheet: %{
          first_name: "Raquel",
          last_name: "Márquez",
          legal_id_kind: "DNI",
          legal_id_number: "11111111",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "-",
          address: "-",
          phone_number: "+54 11111111",
        }
      },
      %{email: "msanchez@hotmail.com",
        password: "msanchez",
        password_confirmation: "msanchez",
        datasheet: %{
          first_name: "Maria",
          last_name: "Sánchez",
          legal_id_kind: "DNI",
          legal_id_number: "11111111",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "-",
          address: "-",
          phone_number: "+54 11111111",
          role: "volunteer",
          status: "approved",
          branch_id: branch2.id
        }
      }
    ]

    Enum.map(users, &insert_user/1)

    mark_as_branch_admin("amartinez@cruzroja.org.ar", branch1)
    mark_as_branch_admin("rmarquez@cruzroja.org.ar", branch2)
  end

  def insert_branches do
    File.stream!("priv/data/branches.csv")
    |> Enum.map(&parse_branch_line/1)
    |> Enum.each(fn [branch_name, address, province, president, authorities, phone, cell, email] ->
      Branch.changeset(%Branch{}, %{name: titleize(branch_name), address: titleize(address <> " - " <> province), president: titleize(president), authorities: titleize(authorities), phone_number: phone, cell_phone_number: cell, email: email}) |> Repo.insert!
    end)
  end

  def insert_countries do
    File.stream!("priv/data/countries.csv")
    |> Enum.map(&(String.replace(&1, "\n", "")))
    |> Enum.each(fn name ->
      Country.changeset(%Country{}, %{name: name})
      |> Repo.insert
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

  def titleize(string) do
    map = String.split(string," ")
    map
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

Seed.run
