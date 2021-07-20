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
