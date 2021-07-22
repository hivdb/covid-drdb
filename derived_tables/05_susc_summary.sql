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
  RETURN ARRAY_TO_STRING(_mutations, '+');
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
    RETURN ARRAY_TO_STRING(_mutations, ' + ');
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
    RETURN ARRAY_TO_STRING(_mutations, ' + ');
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


CREATE FUNCTION csv_agg_sfunc(_accum TEXT, _elem TEXT) RETURNS TEXT AS $$
DECLARE
  _escaped TEXT;
BEGIN
  IF _elem IS NULL THEN
    RETURN _accum;
  END IF;
  _escaped := REPLACE(_elem, '"', '""');
  _escaped := REPLACE(_escaped, E'\n', '\n');
  IF _escaped LIKE '%,%' THEN
    _escaped := '"' || _escaped || '"';
  END IF;
  IF _accum IS NULL THEN
    RETURN _escaped;
  ELSE
    RETURN _accum || ',' || _escaped;
  END IF;
END
$$ LANGUAGE PLPGSQL IMMUTABLE;

CREATE AGGREGATE csv_agg(_elem TEXT) (
  SFUNC = csv_agg_sfunc,
  STYPE = TEXT
);

SELECT
  ref_name,
  rx_name,
  csv_agg(ab.ab_name ORDER BY ab.priority)::VARCHAR AS antibody_names,
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


CREATE TYPE susc_summary_agg_key AS ENUM (
  'article',
  'infected_variant',
  'vaccine',
  'antibody',
  'antibody:indiv',
  'variant',
  'isolate_agg',
  'isolate',
  'potency_type',
  'potency_unit'
);


CREATE FUNCTION array_intersect_count(anyarray, anyarray) RETURNS INTEGER AS $FUNCTION$
  DECLARE
    _r INTEGER;
  BEGIN
    _r := (
      SELECT ARRAY_LENGTH(ARRAY(
        SELECT UNNEST($1)
        INTERSECT
        SELECT UNNEST($2)
      ), 1)
    );
    IF _r IS NULL THEN
      RETURN 0;
    ELSE
      RETURN _r;
    END IF;
  END
$FUNCTION$ LANGUAGE PLPGSQL IMMUTABLE;


CREATE FUNCTION summarize_susc_results(_agg_by susc_summary_agg_key[]) RETURNS VOID AS $$
  DECLARE
    _stmt TEXT;
    _plasma_related_agg_by susc_summary_agg_key[];
    _isolate_related_agg_by susc_summary_agg_key[];
    _ext_col_names TEXT[];
    _ext_col_values TEXT[];
    _ext_joins TEXT[];
    _ext_where TEXT[];
    _ext_group_by TEXT[];
    _ret INTEGER;
  BEGIN
    _stmt := $STMT$
      WITH rows AS(
        INSERT INTO susc_summary (
          aggregate_by,
          num_studies,
          num_samples,
          num_experiments,
          all_studies,
          %1s
        ) SELECT
          $1 AS aggregate_by,
          COUNT(DISTINCT S.ref_name) AS num_studies,
          unique_sum(
            ARRAY_AGG((
              S.ref_name || '$##$' || S.rx_name,
              S.cumulative_count
            )::unique_sum_type)
          ) AS num_samples,
          unique_sum(
            ARRAY_AGG((
              S.ref_name || '$##$' ||
              S.rx_name || '$##$' ||
              S.control_iso_name || '$##$' ||
              S.iso_name || '$##$' ||
              S.potency_type,
              S.cumulative_count
            )::unique_sum_type)
          ) AS num_experiments,
          csv_agg(DISTINCT S.ref_name ORDER BY S.ref_name) AS all_studies,
          %2s
        FROM
          susc_results S %3s
        WHERE %4s
        GROUP BY %5s
        RETURNING 1
      )
      SELECT count(*) FROM rows;
    $STMT$;

    IF 'article' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, 'ref_name');
      _ext_col_values := ARRAY_APPEND(_ext_col_values, 'S.ref_name');
      _ext_group_by := ARRAY_APPEND(_ext_group_by, 'S.ref_name');
    END IF;

    IF 'antibody:indiv' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        rx_type,
        antibody_names,
        antibody_order
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        'antibody' AS rx_type,
        rxab.ab_name AS antibody_names,
        ab.priority AS antibody_order
      $X$);
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN rx_antibodies rxab ON
          S.ref_name = rxab.ref_name AND
          S.rx_name = rxab.rx_name
        JOIN antibodies ab ON rxab.ab_name = ab.ab_name
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        rxab.ab_name,
        ab.priority
      $X$);
    END IF;

    IF 'antibody' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        rx_type,
        antibody_names,
        antibody_order
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        'antibody' AS rx_type,
        ab.antibody_names AS antibody_names,
        ab.antibody_order AS antibody_order
      $X$);
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN rx_antibody_names ab ON
          S.ref_name = ab.ref_name AND
          S.rx_name = ab.rx_name
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        ab.antibody_names,
        ab.antibody_order
      $X$);
    END IF;

    IF 'vaccine' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        rx_type,
        vaccine_name,
        vaccine_order,
        num_subjects
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        'vacc-plasma' AS rx_type,
        rxvp.vaccine_name,
        v.priority AS vaccine_order,
        unique_sum(
          ARRAY_AGG((
            sbj.ref_name || '$##$' || sbj.subject_name,
            sbj.num_subjects
          )::unique_sum_type)
        ) AS num_subjects
      $X$);
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN rx_vacc_plasma rxvp ON
          S.ref_name = rxvp.ref_name AND
          S.rx_name = rxvp.rx_name
        JOIN vaccines v ON
          rxvp.vaccine_name = v.vaccine_name
        JOIN subjects sbj ON
          S.ref_name = sbj.ref_name AND
          rxvp.subject_name = sbj.subject_name
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        rxvp.vaccine_name,
        v.priority
      $X$);
    END IF;

    IF 'infected_variant' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        rx_type,
        infected_var_name,
        num_subjects
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        'conv-plasma' AS rx_type,
        infected.var_name,
        unique_sum(
          ARRAY_AGG((
            sbj.ref_name || '$##$' || sbj.subject_name,
            sbj.num_subjects
          )::unique_sum_type)
        ) AS num_subjects
      $X$);
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN rx_conv_plasma rx ON
          S.ref_name = rx.ref_name AND
          S.rx_name = rx.rx_name
        JOIN subjects sbj ON
          S.ref_name = sbj.ref_name AND
          rx.subject_name = sbj.subject_name
        LEFT JOIN isolates infected ON
          rx.infected_iso_name = infected.iso_name
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        infected.var_name
      $X$);
    END IF;

    _plasma_related_agg_by := ARRAY['vaccine', 'infected_variant'];
    _isolate_related_agg_by := ARRAY['variant', 'isolate_agg', 'isolate'];

    IF _isolate_related_agg_by && _agg_by THEN
      -- query num_subjects when any _plasma_related_agg_by is not used
      IF NOT (_plasma_related_agg_by && _agg_by) THEN
        _ext_col_names := ARRAY_APPEND(_ext_col_names, 'num_subjects');
        _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
          unique_sum(
            ARRAY_AGG((
              sbj.ref_name || '$##$' || sbj.subject_name,
              sbj.num_subjects
            )::unique_sum_type)
          ) AS num_subjects
        $X$);
        _ext_joins := ARRAY_APPEND(_ext_joins, $X$
          LEFT JOIN rx_plasma rxp ON
            S.ref_name = rxp.ref_name AND
            S.rx_name = rxp.rx_name
          LEFT JOIN subjects sbj ON
            S.ref_name = sbj.ref_name AND
            rxp.subject_name = sbj.subject_name
        $X$);
      END IF;
    END IF;

    IF 'variant' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, 'var_name');
      _ext_col_values := ARRAY_APPEND(_ext_col_values, 'target.var_name');
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN isolates target ON
          S.iso_name = target.iso_name
      $X$);
      _ext_where := ARRAY_APPEND(_ext_where, $X$
        target.var_name IS NOT NULL
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, 'target.var_name');
    END IF;

    IF 'isolate_agg' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        iso_type,
        iso_aggkey,
        iso_agg_display,
        var_name
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        CASE WHEN isoagg.num_mutations > 1 THEN
          'combo-muts'
        ELSE
          'indiv-mut'
        END::iso_type_enum AS iso_type,
        isoagg.iso_aggkey AS iso_aggkey,
        isoagg.iso_agg_display AS iso_agg_display,
        isoagg.var_name AS var_name
      $X$);
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN known_isolate_pairs pair ON
          S.control_iso_name = pair.control_iso_name AND
          S.iso_name = pair.iso_name
        JOIN isolate_aggkeys isoagg ON
          pair.iso_aggkey = isoagg.iso_aggkey
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        isoagg.num_mutations,
        isoagg.iso_aggkey,
        isoagg.iso_agg_display,
        isoagg.var_name
      $X$);
    END IF;

    IF 'potency_type' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        potency_type,
        all_fold
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        S.potency_type AS potency_type,
        csv_agg(
          CASE WHEN S.cumulative_count > 1 THEN
            NULL
          ELSE
            S.fold
          END::TEXT
        ) AS all_fold
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        S.potency_type
      $X$);
    END IF;

    IF 'potency_unit' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        potency_unit,
        all_control_potency,
        all_potency
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        S.potency_unit AS potency_unit,
        csv_agg(
          CASE WHEN S.cumulative_count > 1 THEN
            NULL
          ELSE
            S.control_potency
          END::TEXT
        ) AS all_control_potency,
        csv_agg(
          CASE WHEN S.cumulative_count > 1 THEN
            NULL
          ELSE
            S.potency
          END::TEXT
        ) AS all_potency
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        S.potency_unit
      $X$);
    END IF;

    IF 'isolate' = ANY(_agg_by) THEN
      _ext_col_names := ARRAY_APPEND(_ext_col_names, $X$
        iso_type,
        control_iso_name,
        control_iso_display,
        control_var_name,
        iso_name,
        iso_display,
        var_name,
        iso_aggkey,
        iso_agg_display
      $X$);
      _ext_col_values := ARRAY_APPEND(_ext_col_values, $X$
        CASE WHEN pair.num_mutations > 1 THEN
          'combo-muts'
        ELSE
          'indiv-mut'
        END::iso_type_enum AS iso_type,
        pair.control_iso_name,
        ctl_display.iso_display,
        control.var_name,
        pair.iso_name,
        tgt_display.iso_display,
        target.var_name,
        pair.iso_aggkey,
        isoagg.iso_agg_display
      $X$);
      _ext_joins := ARRAY_APPEND(_ext_joins, $X$
        JOIN known_isolate_pairs pair ON
          S.iso_name = pair.iso_name AND
          S.control_iso_name = pair.control_iso_name
        JOIN isolate_aggkeys isoagg ON
          pair.iso_aggkey = isoagg.iso_aggkey
        JOIN isolates target ON
          S.iso_name = target.iso_name
        JOIN isolates control ON
          S.control_iso_name = control.iso_name
        JOIN isolate_displays tgt_display ON
          S.iso_name = tgt_display.iso_name
        JOIN isolate_displays ctl_display ON
          S.control_iso_name = ctl_display.iso_name
      $X$);
      _ext_group_by := ARRAY_APPEND(_ext_group_by, $X$
        pair.num_mutations,
        pair.control_iso_name,
        ctl_display.iso_display,
        control.var_name,
        pair.iso_name,
        tgt_display.iso_display,
        target.var_name,
        pair.iso_aggkey,
        isoagg.iso_agg_display
      $X$);
    END IF;

    IF _ext_where IS NULL THEN
      _ext_where := ARRAY['TRUE'];
    END IF;
    
    _stmt := FORMAT(
      _stmt,
      ARRAY_TO_STRING(_ext_col_names, ', '),
      ARRAY_TO_STRING(_ext_col_values, ', '),
      ARRAY_TO_STRING(_ext_joins, ' '),
      ARRAY_TO_STRING(_ext_where, ' AND '),
      ARRAY_TO_STRING(_ext_group_by, ', ')
    );

    EXECUTE _stmt INTO _ret USING ARRAY_TO_STRING(_agg_by, ',');
    RAISE NOTICE
      'Summarized susc_results by %: % rows created',
      ARRAY_TO_STRING(_agg_by, ' + '),
      _ret;
  END
$$ LANGUAGE PLPGSQL VOLATILE;


DO $$
  DECLARE
    _agg_by_auto_options susc_summary_agg_key[];
    _agg_by susc_summary_agg_key[];
    _rx_agg_by susc_summary_agg_key[];
    _iso_agg_by susc_summary_agg_key[];
  BEGIN
    _agg_by_auto_options := ARRAY[
      'article',
      'infected_variant',
      'vaccine',
      'antibody',
      'antibody:indiv',
      'variant',
      'isolate_agg',
      'potency_type'
    ];
    _rx_agg_by := ARRAY[
      'antibody',
      'antibody:indiv',
      'vaccine',
      'infected_variant'
    ];
    _iso_agg_by := ARRAY[
      'isolate_agg',
      'variant',
      'isolate'
    ];

    FOR _agg_by IN
    SELECT agg_by.agg_by FROM (

      -- combination of one element
      SELECT DISTINCT ARRAY[one] agg_by
      FROM UNNEST(_agg_by_auto_options) one
      WHERE one NOT IN ('potency_type', 'potency_unit')

      UNION
      -- combination of two elements
      SELECT DISTINCT ARRAY[one, two] agg_by
      FROM
        UNNEST(_agg_by_auto_options) one,
        UNNEST(_agg_by_auto_options) two
      WHERE
        one < two AND
        array_intersect_count(ARRAY[one, two], _rx_agg_by) < 2 AND
        array_intersect_count(ARRAY[one, two], _iso_agg_by) < 2

      UNION
      -- combination of three elements
      SELECT DISTINCT ARRAY[one, two, three] agg_by
      FROM
        UNNEST(_agg_by_auto_options) one,
        UNNEST(_agg_by_auto_options) two,
        UNNEST(_agg_by_auto_options) three
      WHERE
        one < two AND two < three AND (
          'potency_type' NOT IN (one, two, three) OR (
            ARRAY[one, two, three] && _rx_agg_by AND
            ARRAY[one, two, three] && _iso_agg_by
          )
        ) AND
        array_intersect_count(ARRAY[one, two, three], _rx_agg_by) < 2 AND
        array_intersect_count(ARRAY[one, two, three], _iso_agg_by) < 2
    ) agg_by
    ORDER BY agg_by.agg_by
    LOOP
      PERFORM summarize_susc_results(_agg_by);
    END LOOP;

    PERFORM summarize_susc_results(ARRAY[
      'article',
      'infected_variant',
      'isolate',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'article',
      'vaccine',
      'isolate',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'antibody',
      'variant',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'antibody',
      'isolate_agg',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'infected_variant',
      'variant',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'infected_variant',
      'isolate_agg',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'vaccine',
      'variant',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);

    PERFORM summarize_susc_results(ARRAY[
      'vaccine',
      'isolate_agg',
      'potency_type',
      'potency_unit'
    ]::susc_summary_agg_key[]);
  END
$$ LANGUAGE PLPGSQL;

-- aggregate by article + infected_variant + control_isolate + isolate + potency_type + potency_unit
-- aggregate by article + vaccine + control_isolate + isolate + potency_type + potency_unit
