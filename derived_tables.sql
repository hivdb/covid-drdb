INSERT INTO rx_conv_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    PTH_isolation.iso_name AS infected_iso_name,
    (PTH_isolation.event_date - PTH_infection.event_date) / 30 AS timing,
    titer,
    PTH_isolation.severity,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    patient_treatments PTRX,
    patient_history PTH_isolation
  LEFT JOIN
    patient_history PTH_infection
  ON
    PTH_infection.ref_name=PTH_isolation.ref_name AND
    PTH_infection.patient_name=PTH_isolation.patient_name AND
    PTH_infection.event='infection'
  WHERE
    RX.ref_name=PTRX.ref_name AND
    RX.rx_name=PTRX.rx_name AND
    PTH_isolation.ref_name=PTRX.ref_name AND
    PTH_isolation.patient_name=PTRX.patient_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_isolation.event='isolation';

UPDATE rx_conv_plasma SET timing=NULL WHERE timing=0;

INSERT INTO rx_vacc_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    PTH_isolation.vaccine_name,
    (PTH_isolation.event_date - PTH_infection.event_date) / 30 AS timing,
    1 AS dosage,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    patient_treatments PTRX,
    patient_history PTH_isolation
  LEFT JOIN
    patient_history PTH_infection
  ON
    PTH_infection.ref_name=PTH_isolation.ref_name AND
    PTH_infection.patient_name=PTH_isolation.patient_name AND
    PTH_infection.event='1st dose'
  WHERE
    RX.ref_name=PTRX.ref_name AND
    RX.rx_name=PTRX.rx_name AND
    PTH_isolation.ref_name=PTRX.ref_name AND
    PTH_isolation.patient_name=PTRX.patient_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_isolation.event='1st dose isolation';


INSERT INTO rx_vacc_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    PTH_isolation.vaccine_name,
    (PTH_isolation.event_date - PTH_infection.event_date) / 30 AS timing,
    2 AS dosage,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    patient_treatments PTRX,
    patient_history PTH_isolation
  LEFT JOIN
    patient_history PTH_infection
  ON
    PTH_infection.ref_name=PTH_isolation.ref_name AND
    PTH_infection.patient_name=PTH_isolation.patient_name AND
    PTH_infection.event='2nd dose'
  WHERE
    RX.ref_name=PTRX.ref_name AND
    RX.rx_name=PTRX.rx_name AND
    PTH_isolation.ref_name=PTRX.ref_name AND
    PTH_isolation.patient_name=PTRX.patient_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_isolation.event='2nd dose isolation';


INSERT INTO rx_vacc_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    PTH_isolation.vaccine_name,
    (PTH_isolation.event_date - PTH_infection.event_date) / 30 AS timing,
    3 AS dosage,
    collection_date,
    cumulative_group
  FROM
    rx_plasma RX,
    patient_treatments PTRX,
    patient_history PTH_isolation
  LEFT JOIN
    patient_history PTH_infection
  ON
    PTH_infection.ref_name=PTH_isolation.ref_name AND
    PTH_infection.patient_name=PTH_isolation.patient_name AND
    PTH_infection.event='3rd dose'
  WHERE
    RX.ref_name=PTRX.ref_name AND
    RX.rx_name=PTRX.rx_name AND
    PTH_isolation.ref_name=PTRX.ref_name AND
    PTH_isolation.patient_name=PTRX.patient_name AND
    collection_date=PTH_isolation.event_date AND
    PTH_isolation.event='3rd dose isolation';

UPDATE rx_vacc_plasma SET timing=NULL WHERE timing=0;

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
