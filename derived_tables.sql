INSERT INTO rx_conv_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    RX.subject_name,
    PTH_isolation.iso_name AS infected_iso_name,
    PTH_isolation.location,
    GREATEST(ROUND((PTH_isolation.event_date - PTH_infection.event_date) / 30.), 1) AS timing,
    titer,
    PTH_infection.severity,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    subject_history PTH_isolation
  LEFT JOIN
    subject_history PTH_infection
  ON
    PTH_infection.ref_name=PTH_isolation.ref_name AND
    PTH_infection.subject_name=PTH_isolation.subject_name AND
    PTH_infection.event='infection'
  WHERE
    PTH_isolation.ref_name=RX.ref_name AND
    PTH_isolation.subject_name=RX.subject_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_isolation.event='isolation';

UPDATE rx_conv_plasma SET timing=NULL WHERE timing=0;

INSERT INTO rx_vacc_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    RX.subject_name,
    (
      SELECT STRING_AGG(DISTINCT vaccine_name, ' + ')
      FROM subject_history SH
      WHERE
        SH.ref_name=RX.ref_name AND
        SH.subject_name=RX.subject_name AND
        SH.event_date<=RX.collection_date AND
        SH.vaccine_name IS NOT NULL
    ) AS vaccine_name,
    PTH_isolation.location,
    GREATEST(ROUND((PTH_isolation.event_date - PTH_vaccination.event_date) / 30.), 1) AS timing,
    1 AS dosage,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    subject_history PTH_isolation,
    subject_history PTH_vaccination
  WHERE
    PTH_isolation.ref_name=RX.ref_name AND
    PTH_isolation.subject_name=RX.subject_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_vaccination.ref_name=PTH_isolation.ref_name AND
    PTH_vaccination.subject_name=PTH_isolation.subject_name AND
    PTH_vaccination.event='1st dose' AND
    PTH_isolation.event='1st dose isolation';


INSERT INTO rx_vacc_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    RX.subject_name,
    (
      SELECT STRING_AGG(DISTINCT vaccine_name, ' + ')
      FROM subject_history SH
      WHERE
        SH.ref_name=RX.ref_name AND
        SH.subject_name=RX.subject_name AND
        SH.event_date<=RX.collection_date AND
        SH.vaccine_name IS NOT NULL
    ) AS vaccine_name,
    PTH_isolation.location,
    GREATEST(ROUND((PTH_isolation.event_date - PTH_vaccination.event_date) / 30.), 1) AS timing,
    2 AS dosage,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    subject_history PTH_isolation,
    subject_history PTH_vaccination
  WHERE
    PTH_isolation.ref_name=RX.ref_name AND
    PTH_isolation.subject_name=RX.subject_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_vaccination.ref_name=PTH_isolation.ref_name AND
    PTH_vaccination.subject_name=PTH_isolation.subject_name AND
    PTH_vaccination.event='2nd dose' AND
    PTH_isolation.event='2nd dose isolation';


INSERT INTO rx_vacc_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    RX.subject_name,
    (
      SELECT STRING_AGG(DISTINCT vaccine_name, ' + ')
      FROM subject_history SH
      WHERE
        SH.ref_name=RX.ref_name AND
        SH.subject_name=RX.subject_name AND
        SH.event_date<=RX.collection_date AND
        SH.vaccine_name IS NOT NULL
    ) AS vaccine_name,
    PTH_isolation.location,
    GREATEST(ROUND((PTH_isolation.event_date - PTH_vaccination.event_date) / 30.), 1) AS timing,
    3 AS dosage,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    subject_history PTH_isolation,
    subject_history PTH_vaccination
  WHERE
    PTH_isolation.ref_name=RX.ref_name AND
    PTH_isolation.subject_name=RX.subject_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_vaccination.ref_name=PTH_isolation.ref_name AND
    PTH_vaccination.subject_name=PTH_isolation.subject_name AND
    PTH_vaccination.event='3rd dose' AND
    PTH_isolation.event='3rd dose isolation';

UPDATE rx_vacc_plasma SET timing=NULL WHERE timing=0;


INSERT INTO susc_results
  SELECT
    pair.ref_name AS ref_name,
    ctl.rx_name AS rx_name,
    pair.control_iso_name AS control_iso_name,
    pair.iso_name AS iso_name,
    1 AS ordinal_number,
    ctl.section AS section,
    CASE WHEN ctl.potency_type IN ('NT50', 'NT80', 'NT90') THEN
      CASE WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN '='::numeric_cmp_enum
           WHEN (ctl.potency > ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN '>'::numeric_cmp_enum
           WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency > tgt.potency_lower_limit) THEN '<'::numeric_cmp_enum
           ELSE '='::numeric_cmp_enum
      END
    ELSE
      CASE WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN '='::numeric_cmp_enum
           WHEN (ctl.potency < ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN '>'::numeric_cmp_enum
           WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency < tgt.potency_upper_limit) THEN '<'::numeric_cmp_enum
           ELSE '='::numeric_cmp_enum
      END
    END AS fold_cmp,

    CASE WHEN ctl.potency_type IN ('NT50', 'NT80', 'NT90') THEN
      ctl.potency / tgt.potency
    ELSE
      tgt.potency / ctl.potency
    END AS fold,

    ctl.potency_type,
    NULL AS resistance_level,

    CASE WHEN ctl.potency_type IN ('NT50', 'NT80', 'NT90') THEN
        CASE WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN 'both'::ineffective_enum
           WHEN (ctl.potency > ctl.potency_lower_limit AND tgt.potency <= tgt.potency_lower_limit) THEN 'experimental'::ineffective_enum
           WHEN (ctl.potency <= ctl.potency_lower_limit AND tgt.potency > tgt.potency_lower_limit) THEN 'control'::ineffective_enum
           ELSE NULL
        END
    ELSE
      CASE WHEN (ctl.potency >= ctl.potency_upper_limit AND tgt.potency >= tgt.potency_upper_limit) THEN 'both'::ineffective_enum
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
    ctl.potency_type = tgt.potency_type AND
    ctl_assay.virus_type = tgt_assay.virus_type;


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
    resistance_level,
    ineffective,
    cumulative_count,
    assay_name,
    date_added
  FROM
    rx_fold;

INSERT INTO antibody_stats
  SELECT ab_name, 'susc_results' AS stat_group, COUNT(*) AS count
  FROM susc_results S, rx_antibodies RX
  WHERE
    RX.ref_name=S.ref_name AND
    RX.rx_name=S.rx_name
  GROUP BY ab_name
  ORDER BY count DESC, ab_name;

INSERT INTO vaccine_stats
  SELECT vaccine_name, 'susc_results' AS stat_group, COUNT(*) AS count
  FROM susc_results S, rx_vacc_plasma RX
  WHERE
    RX.ref_name=S.ref_name AND
    RX.rx_name=S.rx_name
  GROUP BY vaccine_name
  ORDER BY count DESC, vaccine_name;

INSERT INTO conv_plasma_stats
  SELECT 'susc_results' AS stat_group, COUNT(*) AS count
  FROM susc_results S, rx_conv_plasma RX
  WHERE
    RX.ref_name=S.ref_name AND
    RX.rx_name=S.rx_name;

INSERT INTO variant_stats
  SELECT var_name, 'susc_results' AS stat_group, COUNT(*) AS count
  FROM susc_results S, isolates I
  WHERE
    S.iso_name=I.iso_name AND
    var_name IS NOT NULL
  GROUP BY var_name
  ORDER BY count DESC, var_name;

INSERT INTO isolate_stats
  SELECT iso_name, 'susc_results' AS stat_group, COUNT(*) AS count
  FROM susc_results
  GROUP BY iso_name
  ORDER BY count DESC, iso_name;

INSERT INTO article_stats
  SELECT ref_name, 'susc_results' AS stat_group, COUNT(*) AS count
  FROM susc_results
  GROUP BY ref_name
  ORDER BY count DESC, ref_name;
