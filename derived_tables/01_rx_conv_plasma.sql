INSERT INTO rx_conv_plasma
  SELECT
    RX.ref_name,
    RX.rx_name,
    RX.subject_name,
    CASE WHEN PTH_infection.iso_name IS NULL THEN
      PTH_isolation.iso_name
    ELSE
      PTH_infection.iso_name
    END AS infected_iso_name,
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
