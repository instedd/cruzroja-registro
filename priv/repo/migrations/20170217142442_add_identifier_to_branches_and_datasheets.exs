defmodule Registro.Repo.Migrations.AddIdentifierToBranchesAndDatasheets do
  use Ecto.Migration
  alias Registro.Repo

  def up do
    alter table(:branches) do
      add :identifier, :integer
    end

    alter table(:datasheets) do
      add :branch_identifier, :integer
    end

    flush

    Repo.query!("UPDATE branches SET identifier = nextval('branches_seq_num')")

    initialize_datasheet_identifiers!

    create unique_index(:datasheets, [:branch_id, :branch_identifier])

    alter table(:branches) do
      modify :identifier, :integer, null: false
    end
  end

  def down do
    alter table(:branches) do
      remove :identifier
    end

    alter table(:datasheets) do
      remove :branch_identifier
    end
  end

  def initialize_datasheet_identifiers! do
    Repo.query!("""
    CREATE OR REPLACE FUNCTION tmp_next_datasheet_seq_num (_branch_id integer)
    RETURNS integer AS $$
    DECLARE
    _next_val integer;
    BEGIN

    SELECT COALESCE(MAX(value), 0) + 1
    FROM branch_sequences seqs
    WHERE seqs.branch_id = _branch_id
    INTO _next_val;

    INSERT INTO branch_sequences(branch_id, value)
    VALUES (_branch_id, _next_val)
    ON CONFLICT (branch_id) DO
    UPDATE SET
    value = _next_val;

    RETURN _next_val;

    END;
    $$ LANGUAGE plpgsql;
    """)

    branch_ids = Repo.query!("SELECT id FROM branches").rows

    Enum.each(branch_ids, fn [branch_id] ->
      Repo.query!("UPDATE datasheets SET branch_identifier = tmp_next_datasheet_seq_num($1) WHERE branch_id = $1", [branch_id])
    end)

    Repo.query!("DROP FUNCTION tmp_next_datasheet_seq_num(_branch_id integer)")
  end
end
