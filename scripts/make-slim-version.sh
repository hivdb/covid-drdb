#!/bin/bash

DB_FILE=$1

sqlite3 $DB_FILE <<EOF
DELETE FROM subject_plasma;
DELETE FROM rx_potency;
DELETE FROM rx_fold;
DELETE FROM treatments;
DELETE FROM ref_invivo;
DELETE FROM ref_isolate_pairs;
DELETE FROM ref_unpaired_isolates;
DELETE FROM antibody_articles;
DELETE FROM susc_summary;
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
VACUUM
EOF
