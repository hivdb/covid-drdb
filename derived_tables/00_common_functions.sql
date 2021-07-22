CREATE FUNCTION csv_agg_sfunc(_accum TEXT, _elem TEXT) RETURNS TEXT AS $$
DECLARE
  _escaped TEXT;
BEGIN
  IF _elem IS NULL THEN
    RETURN _accum;
  END IF;
  _escaped := REPLACE(_elem, '"', '""');
  _escaped := REPLACE(_escaped, E'\n', '\n');
  IF _escaped LIKE '%,%' THEN
    _escaped := '"' || _escaped || '"';
  END IF;
  IF _accum IS NULL THEN
    RETURN _escaped;
  ELSE
    RETURN _accum || ',' || _escaped;
  END IF;
END
$$ LANGUAGE PLPGSQL IMMUTABLE;

CREATE AGGREGATE csv_agg(_elem TEXT) (
  SFUNC = csv_agg_sfunc,
  STYPE = TEXT
);

CREATE TYPE unique_sum_type AS (
  unikey VARCHAR,
  number INTEGER
);

CREATE FUNCTION unique_sum(unique_sum_type[]) RETURNS INTEGER AS $$
  SELECT SUM(number) FROM (
    SELECT DISTINCT unikey, number FROM UNNEST($1) u
  ) n
$$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION array_intersect_count(anyarray, anyarray) RETURNS INTEGER AS $FUNCTION$
  DECLARE
    _r INTEGER;
  BEGIN
    _r := (
      SELECT ARRAY_LENGTH(ARRAY(
        SELECT UNNEST($1)
        INTERSECT
        SELECT UNNEST($2)
      ), 1)
    );
    IF _r IS NULL THEN
      RETURN 0;
    ELSE
      RETURN _r;
    END IF;
  END
$FUNCTION$ LANGUAGE PLPGSQL IMMUTABLE;


