defmodule Registro.Repo.Migrations.AddAdminGrantToDatasheets do
  use Ecto.Migration

  def up do
    alter table(:datasheets) do
      add :global_grant, :string
    end

    flush

    Registro.Repo.query!("UPDATE datasheets SET global_grant = 'super_admin' WHERE is_super_admin = TRUE")

    alter table(:datasheets) do
      remove :is_super_admin
    end
  end

  def down do
    alter table(:datasheets) do
      add :is_super_admin, :boolean
    end

    flush

    Registro.Repo.query!("UPDATE datasheets SET is_super_admin = TRUE WHERE global_grant = 'super_admin'")
    Registro.Repo.query!("UPDATE datasheets SET is_super_admin = FALSE WHERE is_super_admin IS NULL")

    alter table(:datasheets) do
      remove :global_grant
    end
  end
end
