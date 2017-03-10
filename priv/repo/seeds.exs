# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
alias Registro.{
  Branch,
  Country,
  Datasheet,
  Repo,
  User
}

import Ecto.Query

defmodule Seed do
  def run do
    PgSql.load_functions!

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
          legal_id: "1",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "Administrador de Cruz Roja",
          address: "-",
          phone_number: "+54 11111111",
          global_grant: "super_admin"
        }
       },
      %{email: "amartinez@cruzroja.org.ar",
        password: "amartinez",
        password_confirmation: "amartinez",
        datasheet: %{
          first_name: "Agustín",
          last_name: "Martínez",
          legal_id_kind: "DNI",
          legal_id: "2",
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
          legal_id: "4",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "-",
          address: "-",
          phone_number: "+54 11111111",
          role: "volunteer",
          status: "approved",
          registration_date: ~D[2017-01-01],
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
          legal_id: "5",
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
          legal_id: "6",
          country_id: argentina.id,
          birth_date: ~D[1980-01-01],
          occupation: "-",
          address: "-",
          phone_number: "+54 11111111",
          role: "volunteer",
          status: "approved",
          registration_date: ~D[2017-01-01],
          branch_id: branch2.id
        }
      }
    ]

    Enum.map(users, &insert_user/1)

    mark_as_branch_admin("amartinez@cruzroja.org.ar", branch1)
    mark_as_branch_clerk("amartinez@cruzroja.org.ar", branch2)

    mark_as_branch_admin("rmarquez@cruzroja.org.ar", branch2)
  end

  def insert_branches do
    File.stream!("priv/data/branches.csv")
    |> Enum.map(&parse_branch_line/1)
    |> Enum.each(fn line ->
      [branch_name, address, province, president, authorities, phone, cell, email] = line

      params = %{ name: titleize(branch_name),
                  address: titleize(address <> " - " <> province),
                  president: titleize(president),
                  authorities: titleize(authorities),
                  phone_number: phone,
                  cell_phone_number: cell,
                  email: email,
                  eligible: true }

      Branch.creation_changeset(params) |> Repo.insert!
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
    User.changeset(%User{}, :update, params) |> Repo.insert!
  end

  def mark_as_branch_admin(email, branch) do
    get_user(email).datasheet
    |> Datasheet.make_admin_changeset([branch])
    |> Repo.update!
  end

  def mark_as_branch_clerk(email, branch) do
    get_user(email).datasheet
    |> Datasheet.make_clerk_changeset([branch])
    |> Repo.update!
  end

  def get_user(email) do
    User
    |> preload(:datasheet)
    |> Repo.get_by!(email: email)
  end

  def titleize(string) do
    map = String.split(string," ")
    map
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

Seed.run
