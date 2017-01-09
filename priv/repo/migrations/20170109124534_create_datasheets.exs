defmodule Registro.Repo.Migrations.CreateDatasheets do
  use Ecto.Migration

  alias __MODULE__

  def up do
    create table(:datasheets) do
      add :name, :string
      add :role, :string
      add :status, :string
      add :branch_id, references(:branches)
    end

    alter table(:users) do
      add :datasheet_id, references(:datasheets)
    end

    flush

    Registro.Repo.query!("SELECT id, name, role, status, branch_id FROM users").rows
    |> Enum.each(&CreateDatasheets.insert_datasheet_from_user/1)

    alter table(:users) do
      remove :name
      remove :role
      remove :status
      remove :branch_id
    end
  end

  def down do
    alter table(:users) do
      add :name, :string
      add :role, :string
      add :status, :string
      add :branch_id, references(:branches)
    end

    flush

    Registro.Repo.query!("SELECT id, name, role, status, branch_id FROM datasheets").rows
    |> Enum.each(&CreateDatasheets.embed_datasheet_in_user/1)

    alter table(:users) do
      remove :datasheet_id
    end

    drop table(:datasheets)
  end

  def insert_datasheet_from_user([user_id, name, role, status, branch_id]) do
    insert_result = Registro.Repo.query!("INSERT INTO datasheets (name, role, status, branch_id) VALUES ($1, $2, $3, $4) RETURNING id", [name, role, status, branch_id])
    [[datasheet_id]] = insert_result.rows
    Registro.Repo.query!("UPDATE users SET datasheet_id = $1 WHERE id = $2", [datasheet_id, user_id])
  end

  def embed_datasheet_in_user([datasheet_id, name, role, status, branch_id]) do
    Registro.Repo.query!("UPDATE users SET name = $1, role = $2, status = $3, branch_id = $4 WHERE datasheet_id = $5", [name, role, status, branch_id, datasheet_id])
  end
end
