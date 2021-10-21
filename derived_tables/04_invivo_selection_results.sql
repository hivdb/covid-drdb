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
  FROM subject_history PTH
  JOIN isolate_mutations IM ON
    PTH.iso_name = IM.iso_name
  JOIN subject_history PTH_INF ON
    PTH.ref_name = PTH_INF.ref_name AND
    PTH.subject_name = PTH_INF.subject_name AND
    PTH_INF.event = 'infection'
  JOIN isolates INF_ISO ON
    PTH_INF.iso_name = INF_ISO.iso_name
  WHERE
    PTH.event = 'isolation' AND
    NOT EXISTS (
      SELECT 1
        FROM subject_history PREV_PTH
        JOIN isolate_mutations PREV_IM ON
          PREV_PTH.iso_name = PREV_IM.iso_name
        WHERE
          PREV_PTH.ref_name = PTH.ref_name AND
          PREV_PTH.subject_name = PTH.subject_name AND
          PREV_PTH.event IN ('infection', 'isolation') AND
          PREV_PTH.event_date < PTH.event_date AND
          PREV_IM.gene = IM.gene AND
          PREV_IM.position = IM.position AND
          PREV_IM.amino_acid = IM.amino_acid
    );
