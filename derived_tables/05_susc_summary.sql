CREATE TYPE mutation_type AS (
  gene VARCHAR,
  pos INTEGER,
  aa amino_acid_enum
);


CREATE FUNCTION get_mutation_display(_mutobjs mutation_type[]) RETURNS VARCHAR[] AS $$
DECLARE
  _prev_del_gene VARCHAR;
  _prev_del_pos INTEGER;
  _prev_del_pos_start INTEGER;
  _prev_del VARCHAR;
  _mut VARCHAR;
  _gene VARCHAR;
  _pos INTEGER;
  _aa amino_acid_enum;
  _gene_display VARCHAR;
  _ref_aa amino_acid_enum;
  _mutations VARCHAR[];
BEGIN
  FOR _gene, _pos, _aa, _gene_display, _ref_aa IN
    SELECT mut.gene, mut.pos, mut.aa, g.display_name, ref.amino_acid
    FROM UNNEST(_mutobjs) mut
      JOIN genes AS g ON g.gene = mut.gene
      JOIN ref_amino_acid AS ref ON
        ref.gene = mut.gene AND
        ref.position = mut.pos
    ORDER BY g.gene_order, mut.pos
  LOOP
    IF _aa = 'del' THEN
      IF _prev_del_gene = _gene AND _prev_del_pos + 1 = _pos THEN
        _mut := 'Δ' || _prev_del_pos_start::varchar || '-' || _pos::varchar;
        _prev_del := NULL;
      ELSE
        _mut := 'Δ' || _pos::varchar;
        _prev_del_pos_start = _pos;
      END IF;
      _prev_del_gene = _gene;
      _prev_del_pos = _pos;
    ELSE
      _mut := _ref_aa::varchar || _pos::varchar || _aa::varchar;
    END IF;
    IF _gene != 'S' THEN
      _mut := _gene_display || ':' || _mut;
    END IF;
    IF _prev_del IS NOT NULL THEN
      _mutations := array_append(_mutations, _prev_del);
      _prev_del := NULL;
    END IF;
    IF _aa = 'del' THEN
      _prev_del := _mut;
    ELSE
      _mutations := array_append(_mutations, _mut);
    END IF;
  END LOOP;
  IF _prev_del IS NOT NULL THEN
    _mutations := array_append(_mutations, _prev_del);
  END IF;
  RETURN _mutations;
END
$$ LANGUAGE PLPGSQL IMMUTABLE;


CREATE FUNCTION get_countable_mutations(_mutobjs mutation_type[]) RETURNS VARCHAR[] AS $$
DECLARE
  _prev_gene varchar;
  _gene varchar;
  _gene_order integer;
  _pos integer;
  _pos_end integer;
  _aa amino_acid_enum;
  _mut varchar;
  _mutations varchar[];
BEGIN
  FOR _gene, _gene_order, _pos, _pos_end, _aa IN
    SELECT
      DISTINCT
      mut.gene,
      g.gene_order,
      CASE WHEN
        mut.aa = 'del' AND
        position_start IS NOT NULL
      THEN
        position_start
      ELSE
        mut.pos
      END AS pos_start,
      position_end AS pos_end,
      mut.aa
    FROM UNNEST(_mutobjs) mut
      JOIN genes AS g ON g.gene = mut.gene
      LEFT JOIN known_deletion_ranges dr ON
        dr.gene = mut.gene AND
        mut.pos BETWEEN position_start AND position_end
    WHERE
      NOT EXISTS (
        SELECT 1 FROM ignore_mutations igm
        WHERE
          igm.gene = mut.gene AND
          igm.position = mut.pos AND
          igm.amino_acid = mut.aa
      )
    ORDER BY g.gene_order, pos_start
  LOOP
    IF _aa = 'del' AND _pos_end IS NOT NULL THEN
      _mut := _pos::VARCHAR || '-' || _pos_end::VARCHAR || _aa::VARCHAR;
    ELSE
      _mut := _pos::VARCHAR || _aa::VARCHAR;
    END IF;
    IF _prev_gene IS NULL OR _prev_gene != _gene THEN
      _mut := _gene || ':' || _mut;
    END IF;
    _prev_gene := _gene;
    _mutations := array_append(_mutations, _mut);
  END LOOP;
  RETURN _mutations;
END
$$ LANGUAGE PLPGSQL IMMUTABLE;


CREATE FUNCTION get_isolate_aggkey(my_iso_name VARCHAR, my_control_iso_name VARCHAR) RETURNS VARCHAR AS $$
DECLARE
  _mutobjs mutation_type[];
  _mutations varchar[];
BEGIN
  IF my_control_iso_name IS NULL THEN
    my_control_iso_name := 'Wuhan-Hu-1';
  END IF;
  _mutobjs := (
    SELECT ARRAY_AGG(
      (
        mut.gene,
        mut.position,
        mut.amino_acid
      )::mutation_type
    )
    FROM isolate_mutations mut
    WHERE
      mut.gene = 'S' AND
      mut.iso_name = my_iso_name AND
      NOT EXISTS (
        SELECT 1 FROM isolate_mutations ctl_mut
        WHERE
          ctl_mut.iso_name = my_control_iso_name AND
          ctl_mut.gene = mut.gene AND
          ctl_mut.position = mut.position AND
          ctl_mut.amino_acid = mut.amino_acid
      )
  );
  _mutations := get_countable_mutations(_mutobjs);
  RETURN array_to_string(_mutations, '+');
END
$$ LANGUAGE PLPGSQL IMMUTABLE;

CREATE FUNCTION get_isolate_mutobjs(_iso_name VARCHAR) RETURNS mutation_type[] AS $$
  SELECT ARRAY_AGG(
    (
      mut.gene,
      mut.position,
      mut.amino_acid
    )::mutation_type
  )
  FROM isolate_mutations mut
  WHERE
    mut.gene = 'S' AND
    mut.iso_name = _iso_name
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION get_isolate_display(_iso_name VARCHAR) RETURNS VARCHAR AS $$
DECLARE
  _mutobjs mutation_type[];
  _mutations VARCHAR[];
BEGIN
  _mutobjs := get_isolate_mutobjs(_iso_name);
  _mutations := get_mutation_display(_mutobjs);
  IF _mutations IS NULL OR array_length(_mutations, 1) = 0 THEN
    RETURN 'Wildtype';
  ELSE
    RETURN array_to_string(_mutations, ' + ');
  END IF;
END
$$ LANGUAGE PLPGSQL IMMUTABLE;

SELECT DISTINCT
  control_iso_name,
  iso_name,
  get_isolate_aggkey(iso_name, control_iso_name) AS iso_aggkey,
  ARRAY_LENGTH(
    get_countable_mutations(
      get_isolate_mutobjs(iso_name)
    ),
    1
  ) AS num_mutations
INTO TABLE known_isolate_pairs
FROM ref_isolate_pairs;

SELECT
  iso_name,
  get_isolate_display(iso_name) AS iso_display
INTO TABLE isolate_displays
FROM isolates;


CREATE FUNCTION get_isolate_agg_var_name(_iso_aggkey VARCHAR) RETURNS VARCHAR AS $$
  SELECT var_name
  FROM isolates iso
  WHERE var_name IS NOT NULL AND EXISTS(
    SELECT 1 FROM known_isolate_pairs pair
    WHERE pair.iso_name = iso.iso_name AND pair.iso_aggkey = _iso_aggkey
  )
  LIMIT 1
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION get_isolate_agg_mutobjs(_iso_aggkey VARCHAR) RETURNS mutation_type[] AS $$
  SELECT ARRAY_AGG(
    DISTINCT (
      mut.gene,
      mut.position,
      mut.amino_acid
    )::mutation_type
  )
  FROM
    isolate_mutations mut,
    known_isolate_pairs pair
  WHERE
    mut.gene = 'S' AND
    pair.iso_aggkey = _iso_aggkey AND
    mut.iso_name = pair.iso_name AND
    NOT EXISTS (
      SELECT 1 FROM isolate_mutations ctl_mut
      WHERE
        ctl_mut.iso_name = pair.control_iso_name AND
        ctl_mut.gene = mut.gene AND
        ctl_mut.position = mut.position AND
        ctl_mut.amino_acid = mut.amino_acid
    ) AND
    NOT EXISTS (
      SELECT 1 FROM ignore_mutations igm
      WHERE
        igm.gene = mut.gene AND
        igm.position = mut.position AND
        igm.amino_acid = mut.amino_acid
    )
$$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION get_isolate_agg_display(_iso_aggkey VARCHAR) RETURNS VARCHAR AS $$
DECLARE
  _mutobjs mutation_type[];
  _mutations VARCHAR[];
BEGIN
  _mutobjs := get_isolate_agg_mutobjs(_iso_aggkey);
  _mutations := get_mutation_display(_mutobjs);
  IF _mutations IS NULL OR ARRAY_LENGTH(_mutations, 1) = 0 THEN
    RETURN 'Wildtype';
  ELSE
    RETURN array_to_string(_mutations, ' + ');
  END IF;
END
$$ LANGUAGE PLPGSQL IMMUTABLE;

SELECT DISTINCT
  iso_aggkey,
  ARRAY_LENGTH(
    get_countable_mutations(
      get_isolate_agg_mutobjs(iso_aggkey)
    ),
    1
  ) AS num_mutations,
  get_isolate_agg_display(iso_aggkey) AS iso_agg_display,
  get_isolate_agg_var_name(iso_aggkey) AS var_name
INTO TABLE isolate_aggkeys
FROM known_isolate_pairs;


CREATE FUNCTION array_to_csv(_array TEXT[]) RETURNS TEXT AS $$
DECLARE
  _elem TEXT;
  _escaped TEXT[];
BEGIN
  FOREACH _elem IN ARRAY _array LOOP
    IF _elem IS NULL THEN
      CONTINUE;
    END IF;
    _elem := REPLACE(_elem, '"', '""');
    _elem := REPLACE(_elem, E'\n', '\n');
    IF _elem LIKE '%,%' THEN
      _elem := '"' || _elem || '"';
    END IF;
    _escaped := array_append(_escaped, _elem);
  END LOOP;
  RETURN array_to_string(_escaped, ',');
END
$$ LANGUAGE PLPGSQL IMMUTABLE;

SELECT
  ref_name,
  rx_name,
  array_to_csv(array_agg(ab.ab_name ORDER BY ab.priority))::VARCHAR AS antibody_names,
  MAX(ab.priority) * 10 + COUNT(ab.ab_name) AS antibody_order
INTO TABLE rx_antibody_names
FROM rx_antibodies rxab, antibodies ab
WHERE
  rxab.ab_name = ab.ab_name
GROUP BY ref_name, rx_name;

CREATE TYPE unique_sum_type AS (
  unikey VARCHAR,
  number INTEGER
);


CREATE FUNCTION unique_sum(unique_sum_type[]) RETURNS INTEGER AS $$
  SELECT SUM(number) FROM (
    SELECT DISTINCT unikey, number FROM UNNEST($1) u
  ) n
$$ LANGUAGE SQL IMMUTABLE;


-- aggregate by antibody + iso_agg + potency_type
INSERT INTO susc_summary (
  rx_type,
  iso_type,
  antibody_names,
  antibody_order,
  iso_aggkey,
  iso_agg_display,
  var_name,
  potency_type,
  num_studies,
  num_samples,
  num_experiments,
  all_studies,
  all_fold
) SELECT
  'antibody' AS rx_type,
  CASE WHEN isoagg.num_mutations > 1 THEN
    'combo-muts'
  ELSE
    'indiv-mut'
  END::iso_type_enum AS iso_type,
  ab.antibody_names AS antibody_names,
  ab.antibody_order AS antibody_order,
  isoagg.iso_aggkey AS iso_aggkey,
  isoagg.iso_agg_display AS iso_agg_display,
  isoagg.var_name AS var_name,
  S.potency_type AS potency_type,
  COUNT(DISTINCT S.ref_name) AS num_studies,
  unique_sum(
    ARRAY_AGG((
      S.ref_name || '$##$' || S.rx_name,
      S.cumulative_count
    )::unique_sum_type)
  ) AS num_samples,
  unique_sum(
    ARRAY_AGG((
      S.ref_name || '$##$' || S.rx_name || '$##$' || S.control_iso_name || '$##$' || S.iso_name || '$##$' || S.potency_type,
      S.cumulative_count
    )::unique_sum_type)
  ) AS num_experiments,
  array_to_csv(
    array_agg(S.ref_name ORDER BY S.ref_name)
  ) AS all_studies,
  array_to_csv(array_agg(
    CASE WHEN S.cumulative_count > 1 THEN
      NULL
    ELSE
      S.fold
    END::TEXT
  )) AS all_fold
FROM
  susc_results S
  JOIN rx_antibody_names ab ON
    S.ref_name = ab.ref_name AND
    S.rx_name = ab.rx_name
  JOIN known_isolate_pairs pair ON
    S.control_iso_name = pair.control_iso_name AND
    S.iso_name = pair.iso_name
  JOIN isolate_aggkeys isoagg ON
    pair.iso_aggkey = isoagg.iso_aggkey
GROUP BY
  ab.antibody_names,
  ab.antibody_order,
  isoagg.num_mutations,
  isoagg.iso_aggkey,
  isoagg.iso_agg_display,
  isoagg.var_name,
  S.potency_type;


-- aggregate by antibody + var_name + potency_type
INSERT INTO susc_summary (
  rx_type,
  antibody_names,
  antibody_order,
  var_name,
  potency_type,
  num_studies,
  num_samples,
  num_experiments,
  all_studies,
  all_fold
) SELECT
  'antibody' AS rx_type,
  ab.antibody_names AS antibody_names,
  ab.antibody_order AS antibody_order,
  iso.var_name AS var_name,
  S.potency_type AS potency_type,
  COUNT(DISTINCT S.ref_name) AS num_studies,
  unique_sum(
    ARRAY_AGG((
      S.ref_name || '$##$' || S.rx_name,
      S.cumulative_count
    )::unique_sum_type)
  ) AS num_samples,
  unique_sum(
    ARRAY_AGG((
      S.ref_name || '$##$' || S.rx_name || '$##$' || S.control_iso_name || '$##$' || S.iso_name || '$##$' || S.potency_type,
      S.cumulative_count
    )::unique_sum_type)
  ) AS num_experiments,
  array_to_csv(
    array_agg(S.ref_name ORDER BY S.ref_name)
  ) AS all_studies,
  array_to_csv(array_agg(
    CASE WHEN S.cumulative_count > 1 THEN
      NULL
    ELSE
      S.fold
    END::TEXT
  )) AS all_fold
FROM
  susc_results S
  JOIN rx_antibody_names ab ON
    S.ref_name = ab.ref_name AND
    S.rx_name = ab.rx_name
  JOIN isolates iso ON
    S.iso_name = iso.iso_name
GROUP BY
  ab.antibody_names,
  ab.antibody_order,
  iso.var_name,
  S.potency_type;


-- aggregate by ref_name + infected_var_name + control_iso_name + iso_name + potency_type + potency_unit
INSERT INTO susc_summary (
  rx_type,
  iso_type,
  ref_name,
  infected_var_name,
  control_iso_name,
  control_iso_display,
  control_var_name,
  iso_name,
  iso_display,
  var_name,
  potency_type,
  potency_unit,
  num_studies,
  num_subjects,
  num_samples,
  num_experiments,
  all_control_potency,
  all_potency,
  all_fold
) SELECT
  'conv-plasma' AS rx_type,
  CASE WHEN pair.num_mutations > 1 THEN
    'combo-muts'
  ELSE
    'indiv-mut'
  END::iso_type_enum AS iso_type,
  S.ref_name,
  infected.var_name,
  pair.control_iso_name,
  ctl_display.iso_display,
  control.var_name,
  pair.iso_name,
  tgt_display.iso_display,
  target.var_name,
  S.potency_type,
  S.potency_unit,
  COUNT(DISTINCT S.ref_name) AS num_studies,
  unique_sum(
    ARRAY_AGG((
      sbj.ref_name || '$##$' || sbj.subject_name,
      sbj.num_subjects
    )::unique_sum_type)
  ) AS num_subjects,
  unique_sum(
    ARRAY_AGG((
      S.ref_name || '$##$' || S.rx_name,
      S.cumulative_count
    )::unique_sum_type)
  ) AS num_samples,
  unique_sum(
    ARRAY_AGG((
      S.ref_name || '$##$' || S.rx_name || '$##$' || S.control_iso_name || '$##$' || S.iso_name || '$##$' || S.potency_type,
      S.cumulative_count
    )::unique_sum_type)
  ) AS num_experiments,
  array_to_csv(array_agg(
    CASE WHEN S.cumulative_count > 1 THEN
      NULL
    ELSE
      S.control_potency
    END::TEXT
  )) AS all_control_potency,
  array_to_csv(array_agg(
    CASE WHEN S.cumulative_count > 1 THEN
      NULL
    ELSE
      S.potency
    END::TEXT
  )) AS all_potency,
  array_to_csv(array_agg(
    CASE WHEN S.cumulative_count > 1 THEN
      NULL
    ELSE
      S.fold
    END::TEXT
  )) AS all_fold
FROM
  susc_results S
  JOIN rx_conv_plasma rx ON
    S.ref_name = rx.ref_name AND
    S.rx_name = rx.rx_name
  JOIN subjects sbj ON
    S.ref_name = sbj.ref_name AND
    rx.subject_name = sbj.subject_name
  JOIN known_isolate_pairs pair ON
    S.iso_name = pair.iso_name AND
    S.control_iso_name = pair.control_iso_name
  JOIN isolates target ON
    S.iso_name = target.iso_name
  JOIN isolates control ON
    S.control_iso_name = control.iso_name
  JOIN isolate_displays tgt_display ON
    S.iso_name = tgt_display.iso_name
  JOIN isolate_displays ctl_display ON
    S.control_iso_name = ctl_display.iso_name
  LEFT JOIN isolates infected ON
    rx.infected_iso_name = infected.iso_name
GROUP BY
  pair.num_mutations,
  S.ref_name,
  infected.var_name,
  pair.control_iso_name,
  ctl_display.iso_display,
  control.var_name,
  pair.iso_name,
  tgt_display.iso_display,
  target.var_name,
  S.potency_type,
  S.potency_unit;
