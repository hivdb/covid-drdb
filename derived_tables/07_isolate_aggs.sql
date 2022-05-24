INSERT INTO isolate_aggs
  SELECT
    iso_aggkey,
    iso_agg_display,
    var_name,
    iso_type
  FROM susc_summary
  WHERE aggregate_by = 'isolate_agg';
