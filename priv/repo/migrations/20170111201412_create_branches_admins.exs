defmodule Registro.Repo.Migrations.CreateBranchesAdmins do
  use Ecto.Migration

  def up do
    super_admins_up
    branch_admins_up
  end

  def down do
    branch_admins_down
    super_admins_down
  end

  defp super_admins_up do
    alter table(:datasheets) do
      add :is_super_admin, :boolean, null: false, default: false
    end

    flush

    rows = Registro.Repo.query!("SELECT id FROM datasheets WHERE role = 'super_admin'").rows

    Enum.each(rows, fn([datasheet_id]) ->
      Registro.Repo.query!("UPDATE datasheets SET role = NULL, is_super_admin = TRUE WHERE id = $1", [datasheet_id])
    end)
  end

  defp super_admins_down do
    rows = Registro.Repo.query!("SELECT id FROM datasheets WHERE is_super_admin = TRUE").rows

    Enum.each(rows, fn([datasheet_id]) ->
      Registro.Repo.query!("UPDATE datasheets SET role = 'super_admin' WHERE id = $1", [datasheet_id])
    end)

    alter table(:datasheets) do
      remove :is_super_admin
    end
  end

  defp branch_admins_up do
    create table(:branches_admins) do
      add :branch_id, references(:branches)
      add :datasheet_id, references(:datasheets)
    end

    flush

    rows = Registro.Repo.query!("SELECT id, branch_id FROM datasheets WHERE role = 'branch_admin'").rows

    Enum.each(rows, fn([datasheet_id, branch_id]) ->
      Registro.Repo.query!("INSERT INTO branches_admins (datasheet_id, branch_id) VALUES ($1, $2)", [datasheet_id, branch_id])
      Registro.Repo.query!("UPDATE datasheets SET role = NULL, branch_id = NULL WHERE id = $1", [datasheet_id])
    end)
  end

  defp branch_admins_down do
    rows = Registro.Repo.query!("SELECT datasheet_id, branch_id FROM branches_admins").rows

    Enum.each(rows, fn([datasheet_id, branch_id]) ->
      Registro.Repo.query!("UPDATE datasheets SET role = 'branch_admin', branch_id = $1 WHERE id = $2", [branch_id, datasheet_id])
    end)

    drop table(:branches_admins)
  end
end
