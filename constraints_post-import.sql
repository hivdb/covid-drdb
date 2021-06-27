-- for each subject there must be at least one record in subject_history
CREATE FUNCTION hasSubjectHistory(rname varchar, sname varchar) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM subject_history SH
    WHERE rname = SH.ref_name AND sname = SH.subject_name
  )
$$ LANGUAGE SQL;

ALTER TABLE subjects
  ADD CONSTRAINT chk_non_empty_sbj_history CHECK (
    hasSubjectHistory(ref_name, subject_name) IS TRUE
  );

-- for each iso_name in rx_potency, it must exist in ref_isolate_pairs either as
-- control_iso_name or as iso_name
CREATE FUNCTION isIsolateReferred(rname varchar, iname varchar) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM ref_isolate_pairs P
    WHERE rname = P.ref_name AND (
      iname = P.control_iso_name OR
      iname = P.iso_name
    )
  )
$$ LANGUAGE SQL;

ALTER TABLE rx_potency
  ADD CONSTRAINT chk_isolate_pairs CHECK (
    isIsolateReferred(ref_name, iso_name) IS TRUE
  );
