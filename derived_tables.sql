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
