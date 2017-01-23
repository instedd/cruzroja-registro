defmodule Registro.Repo.Migrations.RenameAuditLogEntriesColumns do
  use Ecto.Migration

  @action_to_codes [
    create: 0,
    update: 1,
    approve: 2,
    reject: 3,
    invite_send: 4,
    invite_confirm: 5,
    branch_admin_granted: 6,
    branch_admin_revoked: 7,
  ]

  def up do
    rename table(:user_audit_log_entries), :user_id, to: :target_datasheet_id
    rename table(:user_audit_log_entries), :actor_id, to: :actor_datasheet_id

    alter table(:user_audit_log_entries) do
      add :action, :string
    end

    flush

    Enum.each(@action_to_codes, fn {key, id} ->
      Registro.Repo.query!("UPDATE user_audit_log_entries SET action = $1 WHERE action_id = $2", [Atom.to_string(key), id])
    end)

    alter table(:user_audit_log_entries) do
      remove :action_id
    end
  end

  def down do
    rename table(:user_audit_log_entries), :target_datasheet_id, to: :user_id
    rename table(:user_audit_log_entries), :actor_datasheet_id, to: :actor_id

    alter table(:user_audit_log_entries) do
      add :action_id, :integer
    end

    flush

    Enum.each(@action_to_codes, fn {key, id} ->
      Registro.Repo.query!("UPDATE user_audit_log_entries SET action_id = $1 WHERE action = $2", [id, Atom.to_string(key)])
    end)

    alter table(:user_audit_log_entries) do
      remove :action
    end

  end

end
