INSERT INTO susc_results
  SELECT
    pair.ref_name AS ref_name,
    ctl.rx_name AS rx_name,
    ctl.rx_name AS rx_group,
    pair.control_iso_name AS control_iso_name,
    pair.iso_name AS iso_name,
    (
      SELECT STRING_AGG(uniqmerged.section, '; ')
        FROM (
          SELECT merged.section
            FROM (
              SELECT ctl.section UNION SELECT tgt.section
            ) AS merged
            GROUP BY merged.section
            ORDER BY merged.section
        ) uniqmerged
    ) AS section,
    CASE WHEN (ctl.potency_type::text LIKE 'NT%' OR ctl.potency_type::text = 'inhibition') THEN
      CASE
        WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN '='::numeric_cmp_enum
        WHEN (ctl.potency > ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN '>'::numeric_cmp_enum
        WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency > tgt.potency_lower_limit) THEN '<'::numeric_cmp_enum
        ELSE '='::numeric_cmp_enum
      END
    ELSE
      CASE
        WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN '='::numeric_cmp_enum
        WHEN (ctl.potency < ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN '>'::numeric_cmp_enum
        WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency < tgt.potency_upper_limit) THEN '<'::numeric_cmp_enum
        ELSE '='::numeric_cmp_enum
      END
    END AS fold_cmp,

    CASE WHEN (ctl.potency_type::text LIKE 'NT%' OR ctl.potency_type::text = 'inhibition') THEN
      ctl.potency / tgt.potency
    ELSE
      tgt.potency / ctl.potency
    END AS fold,

    tgt.potency_type AS potency_type,
    ctl.potency AS control_potency,
    tgt.potency AS potency,
    tgt.potency_unit AS potency_unit,

    NULL AS resistance_level,

    CASE WHEN (ctl.potency_type::text LIKE 'NT%' OR ctl.potency_type::text = 'inhibition') THEN
      CASE
        WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN 'both'::ineffective_enum
        WHEN (ctl.potency > ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN 'experimental'::ineffective_enum
        WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency > tgt.potency_lower_limit) THEN 'control'::ineffective_enum
        ELSE NULL
      END
    ELSE
      CASE
        WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN 'both'::ineffective_enum
        WHEN (ctl.potency < ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN 'experimental'::ineffective_enum
        WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency < tgt.potency_upper_limit) THEN 'control'::ineffective_enum
        ELSE NULL
      END
    END AS ineffective,

    ctl.cumulative_count AS control_cumulative_count,
    tgt.cumulative_count AS cumulative_count,
    ctl.assay_name AS control_assay_name,
    tgt.assay_name,
    ctl.date_added AS date_added
  FROM
    ref_isolate_pairs pair,
    rx_potency ctl
    JOIN assays AS ctl_assay ON ctl_assay.assay_name = ctl.assay_name
    JOIN isolates AS ctl_iso ON ctl.iso_name = ctl_iso.iso_name,
    rx_potency tgt
    JOIN assays AS tgt_assay ON tgt_assay.assay_name = tgt.assay_name
  WHERE
    ctl.ref_name = pair.ref_name AND
    ctl.iso_name = pair.control_iso_name AND
    tgt.ref_name = pair.ref_name AND
    tgt.iso_name = pair.iso_name AND
    ctl.rx_name = tgt.rx_name AND
    (
      (
        ctl.potency_unit IS NULL AND
        tgt.potency_unit IS NULL
      ) OR
      ctl.potency_unit = tgt.potency_unit
    ) AND
    ctl.potency_type = tgt.potency_type AND
    CASE WHEN EXISTS (
      SELECT 1 FROM rx_potency strict_tgt
      WHERE
        tgt.ref_name = strict_tgt.ref_name AND
        tgt.rx_name = strict_tgt.rx_name AND
        tgt.iso_name = strict_tgt.iso_name AND
        tgt.potency_type = strict_tgt.potency_type AND
        ctl.assay_name = strict_tgt.assay_name
    ) THEN
      ctl.assay_name = tgt.assay_name
    ELSE
      ctl_assay.virus_type = tgt_assay.virus_type
    END AND (
      NOT EXISTS (
        SELECT 1 FROM rx_conv_plasma rxcp
        WHERE
          rxcp.ref_name = ctl.ref_name AND
          rxcp.rx_name = ctl.rx_name
      ) OR EXISTS (
        SELECT 1
        FROM
          rx_conv_plasma rxcp
          LEFT JOIN isolates infected ON
            rxcp.infected_iso_name = infected.iso_name
        WHERE
          rxcp.ref_name = ctl.ref_name AND
          rxcp.rx_name = ctl.rx_name AND (
            -- require control.var_name must be wild-type
            ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
            -- unless infected.var_name is the same as control.var_name
            infected.var_name = ctl_iso.var_name OR
            -- or the expected control.var_name hasn't been tested
            NOT EXISTS (
              SELECT 1 FROM rx_potency strict_ctl, isolates strict_ctl_iso
              WHERE
                rxcp.ref_name = strict_ctl.ref_name AND
                rxcp.rx_name = strict_ctl.rx_name AND
                strict_ctl.iso_name = strict_ctl_iso.iso_name AND (
                  strict_ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
                  infected.var_name = strict_ctl_iso.var_name
                )
            )

          )
      )
    ) AND (
      NOT EXISTS (
        SELECT 1 FROM rx_vacc_plasma rxvp
        WHERE
          rxvp.ref_name = ctl.ref_name AND
          rxvp.rx_name = ctl.rx_name
      ) OR EXISTS (
        SELECT 1
        FROM
          rx_vacc_plasma rxvp
          LEFT JOIN isolates infected ON
            rxvp.infected_iso_name = infected.iso_name
        WHERE
          rxvp.ref_name = ctl.ref_name AND
          rxvp.rx_name = ctl.rx_name AND (
            -- require control.var_name must be wild-type
            ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
            -- unless infected.var_name is the same as control.var_name
            infected.var_name = ctl_iso.var_name OR
            -- or the expected control.var_name hasn't been tested
            NOT EXISTS (
              SELECT 1 FROM rx_potency strict_ctl, isolates strict_ctl_iso
              WHERE
                rxvp.ref_name = strict_ctl.ref_name AND
                rxvp.rx_name = strict_ctl.rx_name AND
                strict_ctl.iso_name = strict_ctl_iso.iso_name AND (
                  strict_ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
                  infected.var_name = strict_ctl_iso.var_name
                )
            )
          )
      )
    );


INSERT INTO susc_results
  SELECT
    ref_name,
    rx_name,
    rx_name AS rx_group,
    control_iso_name,
    iso_name,
    section,
    fold_cmp,
    fold,
    potency_type,
    NULL AS control_potency,
    NULL AS potency,
    NULL AS potency_unit,
    resistance_level,
    ineffective,
    NULL AS control_cumulative_count,
    cumulative_count,
    assay_name AS control_asasy_name,
    assay_name,
    date_added
  FROM
    rx_fold;

SELECT
  ref_name,
  rx_name,
  '$$cp$$' ||
  CASE WHEN infected_iso_name IS NULL THEN 'null' ELSE infected_iso_name END || '$$' ||
  CASE WHEN timing IS NULL THEN 0 ELSE timing END || '$$' ||
  CASE WHEN severity IS NULL THEN 'null' ELSE severity::TEXT END || '$$' AS rx_group
  INTO TEMPORARY TABLE rx_groups
  FROM rx_conv_plasma;

INSERT INTO rx_groups
SELECT
  ref_name,
  rx_name,
  '$$vp$$' ||
  CASE WHEN infected_iso_name IS NULL THEN 'null' ELSE infected_iso_name END || '$$' ||
  CASE WHEN vaccine_name IS NULL THEN 'null' ELSE vaccine_name END || '$$' ||
  CASE WHEN timing IS NULL THEN 0 ELSE timing END || '$$' ||
  CASE WHEN dosage IS NULL THEN 0 ELSE dosage END || '$$' AS rx_group
  FROM rx_vacc_plasma;

/*
For mAbs, susc_results should always be linked.
The below query should never be executed.

INSERT INTO rx_groups
SELECT
  ref_name,
  rx_name,
  '$$mab$$' || (
    SELECT STRING_AGG(ab_name, '+')
    FROM (
      SELECT ab_name
        FROM UNNEST(ARRAY_AGG(rx_antibodies.ab_name)) ab_name
        GROUP BY ab_name
        ORDER BY ab_name
    ) uniqsorted
  ) || '$$' AS rx_group
  FROM rx_antibodies
  GROUP BY ref_name, rx_name; */

INSERT INTO unlinked_susc_results
  SELECT
    pot.ref_name,
    pot.rx_name,
    rx_group,
    pot.iso_name,
    pot.assay_name,
    pot.potency_type,
    pot.potency,
    pot.cumulative_count,
    CASE WHEN (pot.potency_type::text LIKE 'NT%' OR pot.potency_type::text = 'inhibition') THEN
      pot.potency <= pot.potency_lower_limit
    ELSE
      pot.potency >= pot.potency_lower_limit
    END AS ineffective
  FROM
    rx_potency AS pot,
    rx_groups AS acc
  WHERE
    pot.ref_name = acc.ref_name AND
    pot.rx_name = acc.rx_name AND
    NOT EXISTS (
      SELECT 1 FROM ref_isolate_pairs pair
      WHERE
        pot.ref_name = pair.ref_name AND (
          (
            pair.control_iso_name = pot.iso_name AND
            pot.rx_name = ANY (
              SELECT pot2.rx_name FROM rx_potency pot2
              WHERE
                pot.ref_name = pot2.ref_name AND
                pair.iso_name = pot2.iso_name
            )
          ) OR (
            pair.iso_name = pot.iso_name AND
            pot.rx_name = ANY (
              SELECT pot2.rx_name FROM rx_potency pot2
              WHERE
                pot.ref_name = pot2.ref_name AND
                pair.control_iso_name = pot2.iso_name
            )
          )
        )
    );


INSERT INTO unlinked_susc_results
  SELECT
    pot.ref_name,
    pot.rx_name,
    rx_group,
    pot.iso_name,
    pot.assay_name,
    pot.potency_type,
    pot.potency,
    pot.cumulative_count,
    CASE WHEN (pot.potency_type::text LIKE 'NT%' OR pot.potency_type::text = 'inhibition') THEN
      pot.potency <= pot.potency_lower_limit
    ELSE
      pot.potency >= pot.potency_lower_limit
    END AS ineffective
  FROM
    rx_potency AS pot,
    rx_groups AS acc
  WHERE
    pot.ref_name = acc.ref_name AND
    pot.rx_name = acc.rx_name AND
    NOT EXISTS (
      SELECT 1 FROM unlinked_susc_results u2
      WHERE
        u2.ref_name = pot.ref_name AND
        u2.rx_name = pot.rx_name AND
        u2.iso_name = pot.iso_name AND
        u2.assay_name = pot.assay_name AND
        u2.potency_type = pot.potency_type
    ) AND
    EXISTS (
      SELECT 1 FROM ref_isolate_pairs pair
      WHERE
        pot.ref_name = pair.ref_name AND (
          (
            pair.control_iso_name = pot.iso_name AND
            pot.rx_name <> ANY (
              SELECT u2.rx_name FROM unlinked_susc_results u2
              WHERE
                pot.ref_name = u2.ref_name AND
                pair.iso_name = u2.iso_name
            )
          ) OR (
            pair.iso_name = pot.iso_name AND
            pot.rx_name <> ANY (
              SELECT u2.rx_name FROM unlinked_susc_results u2
              WHERE
                pot.ref_name = u2.ref_name AND
                pair.control_iso_name = u2.iso_name
            )
          )
        ) AND NOT EXISTS (
          SELECT 1 FROM rx_potency pot2
          WHERE
            pot2.ref_name = pot.ref_name AND
            pot2.rx_name = pot.rx_name AND
            (
              (
                pair.control_iso_name = pot.iso_name AND
                pair.iso_name = pot2.iso_name
              ) OR (
                pair.control_iso_name = pot2.iso_name AND
                pair.iso_name = pot.iso_name
              )
            )
        )
    );

INSERT INTO susc_results
  SELECT
    pair.ref_name AS ref_name,
    NULL AS rx_name,
    ctl_rx_grp.rx_group AS rx_group,
    pair.control_iso_name AS control_iso_name,
    pair.iso_name AS iso_name,
    (
      SELECT STRING_AGG(uniqmerged.section, '; ')
        FROM (
          SELECT merged.section
            FROM (
              SELECT section FROM UNNEST(ARRAY_AGG(ctl.section)) section
              UNION
              SELECT section FROM UNNEST(ARRAY_AGG(tgt.section)) section
            ) AS merged
            GROUP BY merged.section
            ORDER BY merged.section
        ) uniqmerged
    ) AS section,
    '=' AS fold_cmp,
    1 AS fold,
    tgt.potency_type AS potency_type,
    NULL AS control_potency,
    NULL AS potency,
    tgt.potency_unit AS potency_unit,
    NULL AS resistance_level,
    NULL AS ineffective,
    NULL AS control_cumulative_count,
    NULL AS cumulative_count,
    ctl.assay_name AS control_assay_name,
    tgt.assay_name AS assay_name,
    MAX(ctl.date_added) AS date_added
  FROM
    ref_isolate_pairs pair,
    rx_potency ctl
    JOIN assays AS ctl_assay ON ctl_assay.assay_name = ctl.assay_name
    JOIN isolates AS ctl_iso ON ctl.iso_name = ctl_iso.iso_name
    JOIN unlinked_susc_results AS ctl_rx_grp
      ON ctl.ref_name = ctl_rx_grp.ref_name AND ctl.rx_name = ctl_rx_grp.rx_name,
    rx_potency tgt
    JOIN assays AS tgt_assay ON tgt_assay.assay_name = tgt.assay_name
    JOIN unlinked_susc_results AS tgt_rx_grp
      ON tgt.ref_name = tgt_rx_grp.ref_name AND tgt.rx_name = tgt_rx_grp.rx_name
  WHERE
    ctl.ref_name = pair.ref_name AND
    ctl.iso_name = pair.control_iso_name AND
    tgt.ref_name = pair.ref_name AND
    tgt.iso_name = pair.iso_name AND
    ctl_rx_grp.rx_group = tgt_rx_grp.rx_group AND
    ctl_rx_grp.iso_name = ctl.iso_name AND
    tgt_rx_grp.iso_name = tgt.iso_name AND
    ctl_rx_grp.assay_name = ctl.assay_name AND
    tgt_rx_grp.assay_name = tgt.assay_name AND
    ctl_rx_grp.potency_type = ctl.potency_type AND
    tgt_rx_grp.potency_type = tgt.potency_type AND
    (
      (
        ctl.potency_unit IS NULL AND
        tgt.potency_unit IS NULL
      ) OR
      ctl.potency_unit = tgt.potency_unit
    ) AND
    ctl.potency_type = tgt.potency_type AND
    CASE WHEN EXISTS (
      SELECT 1 FROM rx_potency strict_tgt
      WHERE
        tgt.ref_name = strict_tgt.ref_name AND
        tgt.rx_name = strict_tgt.rx_name AND
        tgt.iso_name = strict_tgt.iso_name AND
        tgt.potency_type = strict_tgt.potency_type AND
        ctl.assay_name = strict_tgt.assay_name
    ) THEN
      ctl.assay_name = tgt.assay_name
    ELSE
      ctl_assay.virus_type = tgt_assay.virus_type
    END AND (
      NOT EXISTS (
        SELECT 1 FROM rx_conv_plasma rxcp
        WHERE
          rxcp.ref_name = ctl.ref_name AND
          rxcp.rx_name = ctl.rx_name
      ) OR EXISTS (
        SELECT 1
        FROM
          rx_conv_plasma rxcp
          LEFT JOIN isolates infected ON
            rxcp.infected_iso_name = infected.iso_name
        WHERE
          rxcp.ref_name = ctl.ref_name AND
          rxcp.rx_name = ctl.rx_name AND (
            -- require control.var_name must be wild-type
            ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
            -- unless infected.var_name is the same as control.var_name
            infected.var_name = ctl_iso.var_name OR
            -- or the expected control.var_name hasn't been tested
            NOT EXISTS (
              SELECT 1 FROM rx_potency strict_ctl, isolates strict_ctl_iso
              WHERE
                rxcp.ref_name = strict_ctl.ref_name AND
                rxcp.rx_name = strict_ctl.rx_name AND
                strict_ctl.iso_name = strict_ctl_iso.iso_name AND (
                  strict_ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
                  infected.var_name = strict_ctl_iso.var_name
                )
            )

          )
      )
    ) AND (
      NOT EXISTS (
        SELECT 1 FROM rx_vacc_plasma rxvp
        WHERE
          rxvp.ref_name = ctl.ref_name AND
          rxvp.rx_name = ctl.rx_name
      ) OR EXISTS (
        SELECT 1
        FROM
          rx_vacc_plasma rxvp
          LEFT JOIN isolates infected ON
            rxvp.infected_iso_name = infected.iso_name
        WHERE
          rxvp.ref_name = ctl.ref_name AND
          rxvp.rx_name = ctl.rx_name AND (
            -- require control.var_name must be wild-type
            ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
            -- unless infected.var_name is the same as control.var_name
            infected.var_name = ctl_iso.var_name OR
            -- or the expected control.var_name hasn't been tested
            NOT EXISTS (
              SELECT 1 FROM rx_potency strict_ctl, isolates strict_ctl_iso
              WHERE
                rxvp.ref_name = strict_ctl.ref_name AND
                rxvp.rx_name = strict_ctl.rx_name AND
                strict_ctl.iso_name = strict_ctl_iso.iso_name AND (
                  strict_ctl_iso.var_name IN (SELECT var_name FROM variants WHERE as_wildtype IS TRUE) OR
                  infected.var_name = strict_ctl_iso.var_name
                )
            )
          )
      )
    )
    GROUP BY
      pair.ref_name,
      ctl_rx_grp.rx_group,
      pair.control_iso_name,
      pair.iso_name,
      tgt.potency_type,
      tgt.potency_unit,
      ctl.assay_name,
      tgt.assay_name;


UPDATE susc_results R SET
  control_potency = acc_pot.potency,
  control_cumulative_count = acc_pot.cumulative_count
  FROM (
    SELECT
      grp.ref_name,
      grp.rx_group,
      pot.iso_name,
      pot.assay_name,
      pot.potency_type,
      pot.potency_unit,
      GEOMEAN_WEIGHTED(
        ARRAY_AGG(pot.potency),
        ARRAY_AGG(pot.cumulative_count)
      ) potency,
      SUM(pot.cumulative_count) cumulative_count
    FROM
      rx_potency pot, unlinked_susc_results grp
    WHERE
      grp.ref_name = pot.ref_name AND
      grp.rx_name = pot.rx_name AND
      grp.iso_name = pot.iso_name AND
      grp.assay_name = pot.assay_name AND
      grp.potency_type = pot.potency_type
    GROUP BY
      grp.ref_name,
      grp.rx_group,
      pot.iso_name,
      pot.assay_name,
      pot.potency_type,
      pot.potency_unit
  ) acc_pot
  WHERE
    R.rx_name IS NULL AND
    R.ref_name = acc_pot.ref_name AND
    R.rx_group = acc_pot.rx_group AND
    R.control_iso_name = acc_pot.iso_name AND
    R.control_assay_name = acc_pot.assay_name AND
    R.potency_type = acc_pot.potency_type AND
    (
      (
        R.potency_unit IS NULL AND
        acc_pot.potency_unit IS NULL
      ) OR
      R.potency_unit = acc_pot.potency_unit
    );

UPDATE susc_results R SET
  potency = acc_pot.potency,
  cumulative_count = acc_pot.cumulative_count
  FROM (
    SELECT
      grp.ref_name,
      grp.rx_group,
      pot.iso_name,
      pot.assay_name,
      pot.potency_type,
      pot.potency_unit,
      GEOMEAN_WEIGHTED(
        ARRAY_AGG(pot.potency),
        ARRAY_AGG(pot.cumulative_count)
      ) potency,
      SUM(pot.cumulative_count) cumulative_count
    FROM
      rx_potency pot, unlinked_susc_results grp
    WHERE
      grp.ref_name = pot.ref_name AND
      grp.rx_name = pot.rx_name AND
      grp.iso_name = pot.iso_name AND
      grp.assay_name = pot.assay_name AND
      grp.potency_type = pot.potency_type
    GROUP BY
      grp.ref_name,
      grp.rx_group,
      pot.iso_name,
      pot.assay_name,
      pot.potency_type,
      pot.potency_unit
  ) acc_pot
  WHERE
    R.rx_name IS NULL AND
    R.ref_name = acc_pot.ref_name AND
    R.rx_group = acc_pot.rx_group AND
    R.iso_name = acc_pot.iso_name AND
    R.assay_name = acc_pot.assay_name AND
    R.potency_type = acc_pot.potency_type AND
    (
      (
        R.potency_unit IS NULL AND
        acc_pot.potency_unit IS NULL
      ) OR
      R.potency_unit = acc_pot.potency_unit
    );

UPDATE susc_results SET
  fold = CASE
    WHEN (potency_type::text LIKE 'NT%' OR potency_type::text = 'inhibition') THEN
      control_potency / potency
    ELSE
      potency / control_potency
    END
  WHERE
    rx_name IS NULL;
