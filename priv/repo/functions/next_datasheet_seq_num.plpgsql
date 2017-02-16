CREATE OR REPLACE FUNCTION next_datasheet_seq_num (_branch_id integer)
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
