SELECT
  *,
  -- when comparing two event_date, we need to take into account the
  -- effect of event_date_cmp. e.g. <2021-05-01 should smaller than
  -- =2021-05-01.
  CASE event_date_cmp
    WHEN '<' THEN event_date - 1
    WHEN '>' THEN event_date + 1
    ELSE event_date
  END cmparable_event_date
INTO dup_subject_history
FROM subject_history;

INSERT INTO invivo_selection_results
  SELECT
    PTH.ref_name,
    PTH.subject_name,
    INF_ISO.var_name AS infected_var_name,
    IM.gene,
    IM.position,
    IM.amino_acid,
    CASE WHEN IM.count IS NULL THEN 0 ELSE IM.count END,
    CASE WHEN IM.total IS NULL THEN 0 ELSE IM.total END,
    PTH_INF.event_date AS infection_date,
    PTH.event_date AS appearance_date,
    PTH_INF.severity AS severity
  FROM dup_subject_history PTH
  JOIN isolate_mutations IM ON
    PTH.iso_name = IM.iso_name
  JOIN dup_subject_history PTH_INF ON
    PTH.ref_name = PTH_INF.ref_name AND
    PTH.subject_name = PTH_INF.subject_name AND
    PTH_INF.event = 'infection'
  JOIN isolates INF_ISO ON
    PTH_INF.iso_name = INF_ISO.iso_name
  WHERE
    PTH.event = 'isolation' AND
    EXISTS (
      SELECT 1
        FROM dup_subject_history PREV_PTH
        WHERE
          PREV_PTH.ref_name = PTH.ref_name AND
          PREV_PTH.subject_name = PTH.subject_name AND
          PREV_PTH.event IN ('infection', 'isolation') AND
          -- use cmparable_event_date to take into account of the event_date_cmp
          PREV_PTH.cmparable_event_date < PTH.cmparable_event_date
    ) AND
    NOT EXISTS (
      SELECT 1
        FROM dup_subject_history PREV_PTH
        JOIN isolate_mutations PREV_IM ON
          PREV_PTH.iso_name = PREV_IM.iso_name
        WHERE
          PREV_PTH.ref_name = PTH.ref_name AND
          PREV_PTH.subject_name = PTH.subject_name AND
          PREV_PTH.event IN ('infection', 'isolation') AND
          -- use cmparable_event_date to take into account of the event_date_cmp
          PREV_PTH.cmparable_event_date < PTH.cmparable_event_date AND
          PREV_IM.gene = IM.gene AND
          PREV_IM.position = IM.position AND
          PREV_IM.amino_acid = IM.amino_acid
    );

DROP TABLE dup_subject_history;
