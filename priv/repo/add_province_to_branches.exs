defmodule AddProvinces do
  def titleize(string) do
    map = String.split(string," ")
    map
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def parse_branch_line(line) do
    line
    |> String.replace("\n", "")
    |> String.split(",")
  end

  def run do
    File.stream!("priv/data/branches.csv")
    |> Enum.map(&parse_branch_line/1)
    |> Enum.each(fn line ->
      [branch_name, address, city, president, authorities, phone, cell, email, province] = line

      Registro.Repo.query!("UPDATE branches SET province = $1 WHERE name = $2", [province, titleize(branch_name)])
    end)
  end
end

AddProvinces.run()
