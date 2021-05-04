ALTER TABLE susc_results
  ADD CONSTRAINT chk_fold_resistance_level CHECK (
    (fold_cmp IS NOT NULL AND fold IS NOT NULL AND resistance_level IS NULL) OR -- case 1, fold_cmp/fold are presented
    (fold_cmp IS NULL AND fold IS NULL AND resistance_level IS NOT NULL)        -- case 2, resistance_level is presented
  );
