#!/bin/bash

DB_FILE=$1

sqlite3 $DB_FILE <<EOF
DELETE FROM rx_plasma;
DELETE FROM subject_history;
DELETE FROM antibody_articles;
DELETE FROM antibody_epitopes;
DELETE FROM dms_escape_results;
DELETE FROM dms_ace2_binding;
VACUUM
EOF
