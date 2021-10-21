-- In susc_results, one of fold_cmp/fold or resistance_level should not be NULL
ALTER TABLE susc_results
  ADD CONSTRAINT chk_fold_resistance_level CHECK (
    (
      -- case 1, fold_cmp/fold are presented
      fold_cmp IS NOT NULL AND
      fold IS NOT NULL AND
      resistance_level IS NULL
    ) OR
    (
      -- case 2, resistance_level is presented
      fold_cmp IS NULL AND
      fold IS NULL AND
      resistance_level IS NOT NULL
    )
  );

-- In rx_potency, potency must be greater than 0
CREATE FUNCTION check_potency_nonzero(
  potency NUMERIC(10,3),
  ref_name VARCHAR,
  rx_name VARCHAR,
  iso_name VARCHAR,
  potency_type VARCHAR,
  lower_limit NUMERIC(10,3),
  upper_limit NUMERIC(10,3)
) RETURNS BOOLEAN
AS
$$
DECLARE
  lim NUMERIC(10,3);
  msg VARCHAR;
BEGIN
  IF potency > 0 THEN
    RETURN TRUE;
  END IF;
  lim := lower_limit;
  msg := FORMAT('(potency_lower_limit for %s)', potency_type);
  IF potency_type LIKE 'IC%' THEN
    lim := upper_limit;
    msg := FORMAT('(potency_upper_limit for %s)', potency_type);
  END IF;
  RAISE EXCEPTION E'rx_potency.potency must be greater than 0 (ref_name=\x1b[1m%\x1b[0m rx_name=\x1b[1m%\x1b[0m iso_name=\x1b[1m%\x1b[0m potency=\x1b[1m%\x1b[0m); consider changing it to \x1b[1m%\x1b[0m %', ref_name, rx_name, iso_name, potency, lim, msg;
END;
$$ LANGUAGE PLPGSQL IMMUTABLE;

ALTER TABLE rx_potency
  ADD CONSTRAINT chk_potency_nonzero CHECK (check_potency_nonzero(potency, ref_name, rx_name, iso_name, potency_type::text, potency_lower_limit, potency_upper_limit));

-- In subject_history, vaccine_name must be empty when event is not doses
ALTER TABLE subject_history
  ADD CONSTRAINT chk_vaccine_name CHECK (
    event IN ('1st dose', '2nd dose', '3rd dose') OR
    vaccine_name IS NULL
  );

-- severity should only be presented when event is infection
ALTER TABLE subject_history
  ADD CONSTRAINT chk_severity CHECK (
    event = 'infection' OR
    severity IS NULL
  );

ALTER TABLE rx_potency
  ADD CONSTRAINT chk_potency_limit_and_unit CHECK (
    (
      -- case 1
      potency_type IN ('NT50', 'NT80', 'NT90', 'NT100') AND
      potency_lower_limit IS NOT NULL AND
      potency_unit IS NULL
    ) OR
    (
      -- case 2
      potency_type IN ('IC50', 'IC80', 'IC90', 'IC100') AND
      potency_upper_limit IS NOT NULL AND
      potency_unit IS NOT NULL
    ) OR
    (
      -- case 3
      potency_type IN ('NC20', 'NC') AND
      potency_lower_limit IS NOT NULL AND
      potency_unit IS NOT NULL
    )
  );
