-- for each subject there must be at least one record in subject_history
CREATE FUNCTION hasSubjectHistory(rname varchar, sname varchar) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM subject_history SH
    WHERE rname = SH.ref_name AND sname = SH.subject_name
  )
$$ LANGUAGE SQL;

DO $$
  DECLARE row subjects%rowtype;
  BEGIN
    FOR row in SELECT * FROM subjects LOOP
      IF NOT hasSubjectHistory(row.ref_name, row.subject_name) THEN
        RAISE EXCEPTION E'Subject ref_name=\x1b[1m%\x1b[0m subject_name=\x1b[1m%\x1b[0m doesn''t have any `subject_history`', row.ref_name, row.subject_name;
      END IF;
    END LOOP;
  END
$$;

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

DO $$
  DECLARE row rx_potency%rowtype;
  BEGIN
    FOR row in SELECT * FROM rx_potency LOOP
      IF NOT isIsolateReferred(row.ref_name, row.iso_name) THEN
        RAISE EXCEPTION E'Isolate \x1b[1m%\x1b[0m used by article \x1b[1m%\x1b[0m is neither referred as `control_iso_name` nor `iso_name` in `ref_isolate_pairs` table', row.iso_name, row.ref_name;
      END IF;
    END LOOP;
  END
$$;

CREATE FUNCTION isSuscRecordDerived(ref varchar, rx varchar, iso varchar) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM susc_results R
    WHERE
      ref = R.ref_name AND
      rx = R.rx_name AND (
        iso = R.control_iso_name OR
        iso = R.iso_name
      )
  )
$$ LANGUAGE SQL;

DO $$
  DECLARE row rx_potency%rowtype;
  BEGIN
    FOR row in SELECT * FROM rx_potency LOOP
      IF NOT isSuscRecordDerived(row.ref_name, row.rx_name, row.iso_name) THEN
        RAISE EXCEPTION E'Derived `susc_results` is not found for `rx_potency` ref_name=\x1b[1m%\x1b[0m rx_name=\x1b[1m%\x1b[0m iso_name=\x1b[1m%\x1b[0m; check if the paired control/exp isolate for this rx_name exists, if their potency_type and potency_unit are matched, and if the infected_iso_name matches the control_iso_name presented in the table ref_isolate_pairs', row.ref_name, row.rx_name, row.iso_name;
      END IF;
    END LOOP;
  END
$$;

-- ALTER TABLE rx_potency
--   ADD CONSTRAINT chk_susc_results CHECK (
--     isSuscRecordCreated(ref_name, rx_name, iso_name) IS TRUE
--   );

DO $$
  DECLARE
    _rows "rx_plasma"[];
  BEGIN
    _rows := (
      SELECT ARRAY_AGG(rx) FROM rx_plasma rx
      WHERE NOT EXISTS (
        SELECT 1 FROM subject_history h WHERE
          rx.ref_name = h.ref_name AND
          rx.subject_name = h.subject_name AND
          rx.collection_date = h.event_date AND
          h.event::TEXT LIKE '%isolation'
      )
    );
    IF ARRAY_LENGTH(_rows, 1) > 0 THEN
      RAISE EXCEPTION E'Unmatched records were found in `rx_plasma`. Each `rx_plasma.collection_date` must match an isolation `event_date` from table `subject_history`:\n%', ARRAY_TO_JSON(_rows, TRUE);
    END IF;
  END
$$ LANGUAGE PLPGSQL;


