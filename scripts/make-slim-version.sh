#!/bin/bash

DB_FILE=$1

sqlite3 $DB_FILE <<EOF
DELETE FROM rx_plasma;
DELETE FROM rx_potency WHERE NOT EXISTS (
  SELECT 1 FROM unlinked_susc_results usr WHERE
    usr.ref_name = rx_potency.ref_name AND
    usr.rx_name = rx_potency.rx_name AND
    usr.potency_type = rx_potency.potency_type AND
    usr.iso_name = rx_potency.iso_name AND
    usr.assay_name = rx_potency.assay_name 
);
DELETE FROM rx_fold;
DELETE FROM treatments;
DELETE FROM subject_history;
DELETE FROM ref_isolate_pairs;
DELETE FROM ref_unpaired_isolates;
DELETE FROM antibody_articles;
DELETE FROM dms_escape_results;
DELETE FROM dms_ace2_binding;
VACUUM
EOF
