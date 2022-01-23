-- B.1.177.75, B.1.160 and D.2 can only be used as infected variants
-- The reason: Each has only D614G + one Spike mutation which can be mixed
-- with a single mutation isolate
DO $$
  DECLARE row isolates%rowtype;
  BEGIN
    FOR row IN SELECT * FROM isolates iso WHERE
      var_name IN ('B.1.177.75', 'B.1.160', 'D.2') AND (
        EXISTS (
          SELECT 1 FROM rx_potency pot WHERE
            pot.iso_name=iso.iso_name
        ) OR
        EXISTS (
          SELECT 1 FROM rx_fold f WHERE
            f.control_iso_name=iso.iso_name OR
            f.iso_name=iso.iso_name
        )
      )
    LOOP
      RAISE EXCEPTION E'Isolate of variant \x1b[1m%\x1b[0m can be only used as an infected isolate in subject_history. Unlink \x1b[1m%\x1b[0m from \x1b[1m%\x1b[0m to be used in rx_potency or rx_fold.', row.var_name, row.iso_name, row.var_name;
    END LOOP;
  END
$$;

-- rx_type must not be NULL
ALTER TABLE susc_results ALTER COLUMN rx_type SET NOT NULL;

-- for each variant with consensus_availability is TRUE, at least 1 consensus must exist
DO $$
  DECLARE row variants%rowtype;
  BEGIN
    FOR row in SELECT * FROM variants V
    WHERE
      V.var_name != 'B' AND
      V.consensus_availability IS TRUE AND
      NOT EXISTS(
        SELECT 1 FROM variant_consensus C WHERE
          C.var_name = V.var_name
        )
    LOOP
      RAISE EXCEPTION E'Variant \x1b[1m%\x1b[0m should have at least one variant_consensus record. Use `\x1b[1mmake sync-varcons\x1b[0m` to correct this error.', row.var_name;
    END LOOP;
  END
$$;

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
    FOR row IN SELECT * FROM subjects LOOP
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
  ) OR EXISTS (
    SELECT 1 FROM ref_unpaired_isolates UP
    WHERE
      rname = UP.ref_name AND
      iname = UP.iso_name
  )
$$ LANGUAGE SQL;

DO $$
  DECLARE row rx_potency%rowtype;
  BEGIN
    FOR row IN SELECT * FROM rx_potency LOOP
      IF NOT isIsolateReferred(row.ref_name, row.iso_name) THEN
        RAISE EXCEPTION E'Isolate \x1b[1m%\x1b[0m used by article \x1b[1m%\x1b[0m is neither referred as `control_iso_name` nor `iso_name` in `ref_isolate_pairs` table', row.iso_name, row.ref_name;
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

DO $$
  DECLARE row rx_potency%rowtype;
  BEGIN
    FOR row IN SELECT * FROM rx_potency pot JOIN rx_antibodies ab ON pot.ref_name = ab.ref_name AND pot.rx_name = ab.rx_name LOOP
      IF row.potency_type::text NOT LIKE 'IC%' THEN
        RAISE EXCEPTION E'An experiment record of monoclonal antibody must use IC50/IC80/ICXX as its `potency_type`. However, ref_name=\x1b[1m%\x1b[0m rx_name=\x1b[1m%\x1b[0m iso_name=\x1b[1m%\x1b[0m has potency_type=\x1b[1m%\x1b[0m.', row.ref_name, row.rx_name, row.iso_name, row.potency_type;
      END IF;
    END LOOP;
    FOR row IN SELECT * FROM rx_potency pot JOIN rx_plasma plasma ON pot.ref_name = plasma.ref_name AND pot.rx_name = plasma.rx_name LOOP
      IF (row.potency_type::text NOT LIKE 'NT%' AND row.potency_type::text NOT LIKE 'NC%') THEN
        RAISE EXCEPTION E'An experiment record of plasma antibody must use NT50/NT80/NTXX/NCXX as its `potency_type`. However, ref_name=\x1b[1m%\x1b[0m rx_name=\x1b[1m%\x1b[0m iso_name=\x1b[1m%\x1b[0m has potency_type=\x1b[1m%\x1b[0m.', row.ref_name, row.rx_name, row.iso_name, row.potency_type;
      END IF;
    END LOOP;
  END
$$;

DO $$
  DECLARE row rx_fold%rowtype;
  BEGIN
    FOR row IN SELECT * FROM rx_fold fold JOIN rx_antibodies ab ON fold.ref_name = ab.ref_name AND fold.rx_name = ab.rx_name LOOP
      IF row.potency_type::text NOT LIKE 'IC%' THEN
        RAISE EXCEPTION E'An experiment record of monoclonal antibody must use IC50/IC80/ICXX as its `potency_type`. However, ref_name=\x1b[1m%\x1b[0m rx_name=\x1b[1m%\x1b[0m iso_name=\x1b[1m%\x1b[0m has potency_type=\x1b[1m%\x1b[0m.', row.ref_name, row.rx_name, row.iso_name, row.potency_type;
      END IF;
    END LOOP;
    FOR row IN SELECT * FROM rx_fold fold JOIN rx_plasma plasma ON fold.ref_name = plasma.ref_name AND fold.rx_name = plasma.rx_name LOOP
      IF (row.potency_type::text NOT LIKE 'NT%' AND row.potency_type::text NOT LIKE 'NC%') THEN
        RAISE EXCEPTION E'An experiment record of plasma antibody must use NT50/NT80/NTXX/NCXX as its `potency_type`. However, ref_name=\x1b[1m%\x1b[0m rx_name=\x1b[1m%\x1b[0m iso_name=\x1b[1m%\x1b[0m has potency_type=\x1b[1m%\x1b[0m.', row.ref_name, row.rx_name, row.iso_name, row.potency_type;
      END IF;
    END LOOP;
  END
$$;

DO $$
  DECLARE _iso_aggkey VARCHAR;
  DECLARE _iso_aggkeys VARCHAR[];
  DECLARE _iso_names VARCHAR[];
  BEGIN
    _iso_aggkeys := (
      SELECT ARRAY_AGG(iso_aggkey) FROM (
        SELECT
          iso_aggkey,
          COUNT(
            DISTINCT CASE WHEN var_name IS NULL THEN '__NULL_PH' ELSE var_name END
          ) AS num_variants
          FROM isolate_pairs pair, isolates iso
          WHERE pair.iso_name = iso.iso_name
          GROUP BY iso_aggkey
      ) numvars
      WHERE num_variants > 1 AND iso_aggkey IS NOT NULL
    );
    FOREACH _iso_aggkey IN ARRAY _iso_aggkeys LOOP
      _iso_names := (
        SELECT ARRAY_AGG(DISTINCT iso_name) FROM isolate_pairs WHERE iso_aggkey = _iso_aggkey
      );
      RAISE WARNING E'Following isolates are identical at Spike mutation level but were assigned different var_name: \x1b[1m%\x1b[0m', ARRAY_TO_STRING(_iso_names, ', ');
    END LOOP;
  END
$$ LANGUAGE PLPGSQL;

DO $$
  DECLARE _ref_with_unused_rx_plasma VARCHAR;
  DECLARE _unused_rx_plasma VARCHAR;
  BEGIN
    FOR _ref_with_unused_rx_plasma in SELECT DISTINCT RXP.ref_name
    FROM rx_plasma RXP
    WHERE
      NOT EXISTS (
        SELECT 1 FROM susc_results S WHERE
          RXP.ref_name = S.ref_name AND
          RXP.rx_name = S.rx_name
      ) AND NOT EXISTS (
        SELECT 1 FROM unlinked_susc_results UnS WHERE
          RXP.ref_name = UnS.ref_name AND
          RXP.rx_name = UnS.rx_name
      ) AND NOT EXISTS (
        SELECT 1 FROM subject_treatments SbjRx WHERE
          RXP.ref_name = SbjRx.ref_name AND
          RXP.rx_name = SbjRx.rx_name
      ) AND NOT EXISTS (
        SELECT 1 FROM invitro_selection_results IVRx WHERE
          RXP.ref_name = IVRx.ref_name AND
          RXP.rx_name = IVRx.rx_name
      )
    LOOP
      _unused_rx_plasma := (
        SELECT STRING_AGG(rx_name, ', ')
        FROM rx_plasma RXP
        WHERE
          NOT EXISTS (
            SELECT 1 FROM susc_results S WHERE
              RXP.ref_name = S.ref_name AND
              RXP.rx_name = S.rx_name
          ) AND NOT EXISTS (
            SELECT 1 FROM unlinked_susc_results UnS WHERE
              RXP.ref_name = UnS.ref_name AND
              RXP.rx_name = UnS.rx_name
          ) AND NOT EXISTS (
            SELECT 1 FROM subject_treatments SbjRx WHERE
              RXP.ref_name = SbjRx.ref_name AND
              RXP.rx_name = SbjRx.rx_name
          ) AND NOT EXISTS (
            SELECT 1 FROM invitro_selection_results IVRx WHERE
              RXP.ref_name = IVRx.ref_name AND
              RXP.rx_name = IVRx.rx_name
          ) AND RXP.ref_name = _ref_with_unused_rx_plasma
      );
      RAISE WARNING E'Following rx_plasma are not used by reference \x1b[1m%\x1b[0m: \x1b[1m%\x1b[0m', _ref_with_unused_rx_plasma, _unused_rx_plasma;
    END LOOP;
  END
$$ LANGUAGE PLPGSQL;


