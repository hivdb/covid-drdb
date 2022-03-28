INSERT INTO rx_conv_plasma
  SELECT
    SbjP.ref_name,
    SbjP.rx_name,
    SbjP.subject_name,
    SbjInf.infected_var_name,
    SbjP.location,
    GREATEST(ROUND((SbjP.event_date - SbjInf.event_date) / 30.), 1) AS timing,
    SbjInf.severity,
    SbjP.collection_date,
    SbjP.cumulative_group
  FROM
    subject_plasma SbjP,
    subject_infections SbjInf
  WHERE
    SbjInf.ref_name = SbjP.ref_name AND
    SbjInf.subject_name = SbjP.subject_name AND
    SbjInf.infection_date <= SbjP.collection_date AND
    NOT EXISTS (
      SELECT 1 FROM subject_infections SbjInfNext
      WHERE
        SbjInfNext.ref_name=SbjP.ref_name AND
        SbjInfNext.subject_name=SbjP.subject_name AND
        SbjInfNext.infection_date <= SbjP.collection_date AND
        SbjInf.infection_date < SbjInfNext.infection_date
    )

UPDATE rx_conv_plasma SET timing=NULL WHERE timing=0;
