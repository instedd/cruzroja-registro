defmodule Registro.Repo.Migrations.CreateIdentifierSequences do
  use Ecto.Migration

  def up do
    Registro.Repo.query!("CREATE SEQUENCE branches_seq_num MINVALUE 100;")

    create table(:branch_sequences) do
      add :branch_id, references(:branches), unique: true
      add :value, :integer, default: 0
    end

    create unique_index(:branch_sequences, [:branch_id])
  end

  def down do
    Registro.Repo.query!("DROP SEQUENCE branches_seq_num;")
    drop table(:branch_sequences)
  end
end
