#!/bin/bash

DB_FILE=$1

sqlite3 "$DB_FILE" "DROP TABLE IF EXISTS antibody_articles;"
