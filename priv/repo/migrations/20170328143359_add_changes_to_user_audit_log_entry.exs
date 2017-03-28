defmodule Registro.Repo.Migrations.AddChangesToUserAuditLogEntry do
  use Ecto.Migration

  def change do
    alter table(:user_audit_log_entries) do
      add :changes, {:array, :string}
    end
  end
end
