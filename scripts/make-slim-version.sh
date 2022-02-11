#!/bin/bash

set -e

DB_FILE=$1

SUSC_SUMMARY_VARCHARS="aggregate_by
rx_type
iso_type
ref_name
antibody_names
vaccine_name
subject_species
infected_var_name
control_iso_name
control_iso_display
control_var_name
iso_name
iso_display
var_name
iso_aggkey
iso_agg_display
position
potency_type
potency_unit"

SUSC_SUMMARY_INTEGERS="
antibody_order
vaccine_order
vaccine_dosage
timing
num_studies
num_subjects
num_samples
num_experiments
"

SUSC_SUMMARY_ALLCOLS=$(
sqlite3 $DB_FILE <<EOF | awk -F'|' '{print $2}'
PRAGMA TABLE_INFO(susc_summary)
EOF
)

sqlite3 $DB_FILE <<EOF
DELETE FROM rx_plasma;
DELETE FROM rx_potency;
DELETE FROM rx_fold;
DELETE FROM treatments;
DELETE FROM subject_history;
DELETE FROM ref_invivo;
DELETE FROM ref_isolate_pairs;
DELETE FROM ref_unpaired_isolates;
DELETE FROM antibody_articles;
DELETE FROM dms_escape_results AS d WHERE NOT EXISTS (
  SELECT 1 FROM amino_acid_prevalence p
  WHERE
    proportion > 0.00001 AND
    d.gene = p.gene AND
    d.position = p.position AND
    d.amino_acid = p.amino_acid
) OR escape_score < 0.1;
DELETE FROM dms_ace2_binding AS d WHERE NOT EXISTS (
  SELECT 1 FROM dms_escape_results p
  WHERE
    d.gene = p.gene AND
    d.position = p.position AND
    d.amino_acid = p.amino_acid
);
DELETE FROM amino_acid_prevalence;
DELETE FROM isolate_mutations WHERE gene != 'S';
DELETE FROM invivo_selection_results WHERE gene != 'S';

ALTER TABLE susc_summary RENAME TO orig_susc_summary;

$(echo -e "$SUSC_SUMMARY_VARCHARS" | while read col; do
  echo "
    CREATE TABLE susc_summary__${col} AS
      SELECT ROW_NUMBER() OVER (ORDER BY ${col}) AS ${col}_id, ${col}
      FROM (
        SELECT DISTINCT ${col} FROM orig_susc_summary ORDER BY ${col}
      );
    CREATE INDEX susc_summary__${col}_id ON susc_summary__${col} (${col}_id);
    CREATE INDEX susc_summary__${col}_text ON susc_summary__${col} (${col});
  "
done)

CREATE TABLE susc_summary_using_ids AS
  SELECT
    $(echo -e "$SUSC_SUMMARY_ALLCOLS" | while read col; do
      flag=0
      while read varchar; do
        if [[ "$col" = "$varchar" ]]; then
          flag=1
        fi
      done <<< "$(echo -e "$SUSC_SUMMARY_VARCHARS")"

      while read varchar; do
        if [[ "$col" = "$varchar" ]]; then
          flag=2
        fi
      done <<< "$(echo -e "$SUSC_SUMMARY_INTEGERS")"
      if [ $flag -eq 0 ]; then
        echo $col
      elif [ $flag -eq 1 ]; then
        echo "${col}_id"
      else
        echo "CAST(${col} AS INTEGER) AS ${col}"
      fi
    done | paste -sd "," -)
  FROM orig_susc_summary
  $(echo -e "$SUSC_SUMMARY_VARCHARS" | while read col; do
    echo "
      JOIN susc_summary__${col} ON
        orig_susc_summary.${col} = susc_summary__${col}.${col} OR
        orig_susc_summary.${col} IS susc_summary__${col}.${col}
    "
  done);

CREATE VIEW susc_summary AS
  SELECT
    $(echo -e "$SUSC_SUMMARY_ALLCOLS" | paste -sd "," -)
  FROM susc_summary_using_ids
  $(echo -e "$SUSC_SUMMARY_VARCHARS" | while read col; do
    echo "
      JOIN susc_summary__${col} ON
        susc_summary_using_ids.${col}_id = susc_summary__${col}.${col}_id
    "
  done);

DROP TABLE orig_susc_summary;

VACUUM
EOF
