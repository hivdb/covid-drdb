#!/bin/bash

DB_FILE=$1

sqlite3 $DB_FILE <<EOF
PRAGMA writable_schema = 1;
DELETE FROM sqlite_master WHERE name NOT LIKE '%resistance_mutation%' AND name NOT LIKE '%ref_amino_acid%' AND name NOT IN ('antibodies', 'compounds');
PRAGMA writable_schema = 0;
VACUUM;
EOF
