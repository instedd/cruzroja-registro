defmodule Registro.Repo.Migrations.RemoveUnlockableWithToken do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :unlock_token
    end
  end
end
