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
    )
  );
