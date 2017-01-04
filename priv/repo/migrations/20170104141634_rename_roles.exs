defmodule Registro.Repo.Migrations.RenameRoles do
  use Ecto.Migration

  def up do
    execute "UPDATE users SET role = 'super_admin' where role = 'administrator'"
    execute "UPDATE users SET role = 'branch_admin' where role = 'branch_employee'"
  end

  def down do
    execute "UPDATE users SET role = 'administrator' where role = 'super_admin'"
    execute "UPDATE users SET role = 'branch_employee' where role = 'branch_admin'"
  end
end
