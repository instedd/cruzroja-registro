defmodule PgSql do

  @functions ~w[next_datasheet_seq_num]

  def load_functions! do
    Enum.each(@functions, fn func_name ->
      source_file = "priv/repo/functions/#{func_name}.plpgsql"
      source = File.read! source_file
      Registro.Repo.query! source
    end)
  end

  def next_branch_seq_num do
    case Registro.Repo.query("SELECT nextval('branches_seq_num')") do
      {:ok, %Postgrex.Result{rows: [[value]]}} ->
        {:ok, value}
      _ ->
        {:error, "Invalid result from database"}
    end
  end

  def next_datasheet_seq_num(branch_id) do
    case Registro.Repo.query("SELECT next_datasheet_seq_num($1)", [branch_id]) do
      {:ok, %Postgrex.Result{rows: [[value]]}} ->
        {:ok, value}
      _ ->
        {:error, "Invalid result from database"}
    end
  end
end
