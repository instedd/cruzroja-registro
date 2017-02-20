defmodule PgSql do

  alias Registro.Repo

  @source_file "priv/repo/functions.sql"

  def load_functions! do
    @source_file
    |> File.read!
    |> Repo.query!
  end

  def next_branch_seq_num do
    case Repo.query("SELECT nextval('branches_seq_num')") do
      {:ok, %Postgrex.Result{rows: [[value]]}} ->
        {:ok, value}
      _ ->
        {:error, "Invalid result from database"}
    end
  end

  def next_datasheet_seq_num(branch_id) do
    case Repo.query("SELECT next_datasheet_seq_num($1)", [branch_id]) do
      {:ok, %Postgrex.Result{rows: [[value]]}} ->
        {:ok, value}
      _ ->
        {:error, "Invalid result from database"}
    end
  end
end
