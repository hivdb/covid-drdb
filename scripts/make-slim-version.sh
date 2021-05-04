#!/bin/bash

DB_FILE=$1

sqlite3 $DB_FILE <<EOF
DELETE FROM antibody_articles;
DELETE FROM dms_escape_results;
VACUUM
EOF
