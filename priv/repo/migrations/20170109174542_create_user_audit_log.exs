defmodule Registro.Repo.Migrations.CreateUserAuditLog do
  use Ecto.Migration

  def change do
    create table(:user_audit_log_entries) do
      add :user_id, references(:users)
      add :actor_id, references(:users)
      add :action_id, :integer

      timestamps()
    end
    create index(:user_audit_log_entries, [:user_id])
    create index(:user_audit_log_entries, [:actor_id])
  end
end
