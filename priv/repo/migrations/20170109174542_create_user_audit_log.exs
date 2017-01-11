defmodule Registro.Repo.Migrations.CreateUserAuditLog do
  use Ecto.Migration

  def change do
    create table(:user_audit_log_entries) do
      add :user_id, references(:datasheets)
      add :actor_id, references(:datasheets)
      add :action_id, :integer

      timestamps()
    end
  end
end
