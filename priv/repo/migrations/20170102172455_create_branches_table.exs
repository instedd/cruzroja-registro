defmodule Registro.Repo.Migrations.CreateBranchesTable do
  use Ecto.Migration

  def up do
    create table(:branches) do
      add :name, :string
      timestamps()
    end

    create unique_index(:branches, [:name])

    rename table(:users), :branch, to: :branch_id

    alter table(:users) do
      modify :branch_id, references(:branches)
    end
  end

  def down do
    alter table(:users) do
      modify :branch_id, :integer
    end

    execute "ALTER TABLE users DROP CONSTRAINT users_branch_id_fkey"

    rename table(:users), :branch_id, to: :branch

    drop table(:branches)
  end
end
