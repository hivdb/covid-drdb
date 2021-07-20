INSERT INTO susc_results
  SELECT
    pair.ref_name AS ref_name,
    ctl.rx_name AS rx_name,
    pair.control_iso_name AS control_iso_name,
    pair.iso_name AS iso_name,
    1 AS ordinal_number,
    ctl.section AS section,
    CASE WHEN ctl.potency_type::text LIKE 'NT%' THEN
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

    CASE WHEN ctl.potency_type::text LIKE 'NT%' THEN
      ctl.potency / tgt.potency
    ELSE
      tgt.potency / ctl.potency
    END AS fold,

    tgt.potency_type AS potency_type,
    ctl.potency AS control_potency,
    tgt.potency AS potency,
    tgt.potency_unit AS potency_unit,

    NULL AS resistance_level,

    CASE WHEN ctl.potency_type::text LIKE 'NT%' THEN
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

    ctl.cumulative_count AS cumulative_count,
    ctl.assay_name,
    ctl.date_added AS date_added
  FROM
    ref_isolate_pairs pair,
    rx_potency ctl JOIN assays AS ctl_assay ON ctl_assay.assay_name = ctl.assay_name,
    rx_potency tgt JOIN assays AS tgt_assay ON tgt_assay.assay_name = tgt.assay_name
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
    END;


INSERT INTO susc_results
  SELECT
    ref_name,
    rx_name,
    control_iso_name,
    iso_name,
    1 AS ordinal_number,
    section AS section,
    fold_cmp,
    fold,
    potency_type,
    NULL as control_potency,
    NULL as potency,
    NULL as potency_unit,
    resistance_level,
    ineffective,
    cumulative_count,
    assay_name,
    date_added
  FROM
    rx_fold;
