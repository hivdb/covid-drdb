#! /bin/bash

set -e

VERSION=$1

pipenv run python scripts/db_to_sqlite.py "postgresql://postgres@covid-drdb-devdb:5432/postgres" /local/covid-drdb-$VERSION.db --all
echo "Written build/covid-drdb-$VERSION.db"
ln -s covid-drdb-$VERSION.db /local/covid-drdb-latest.db
echo "build/covid-drdb-latest.db -> covid-drdb-$VERSION.db"
# cp -v local/covid-drdb-$VERSION.db ../chiro-cms/downloads/covid-drdb/$VERSION.db
# rm ../chiro-cms/downloads/covid-drdb/latest.db 2>/dev/null || true
# ln -vs $VERSION.db ../chiro-cms/downloads/covid-drdb/latest.db

cp /local/covid-drdb-$VERSION.db /local/covid-drdb-$VERSION-slim.db
./scripts/make-slim-version.sh /local/covid-drdb-$VERSION-slim.db
echo "Written build/covid-drdb-$VERSION-slim.db"
# cp -v local/covid-drdb-$VERSION-slim.db ../chiro-cms/downloads/covid-drdb/$VERSION-slim.db
# rm ../chiro-cms/downloads/covid-drdb/latest-slim.db 2>/dev/null || true
# ln -vs $VERSION-slim.db ../chiro-cms/downloads/covid-drdb/latest-slim.db

mkdir -p build/
mv /local/*.db build/
