SELECT
  iso_aggkey,
  iso_agg_display,
  var_name,
  iso_type
INTO TABLE isolate_aggs
FROM susc_summary
WHERE aggregate_by = 'isolate_agg';
