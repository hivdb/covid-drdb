## Create & release DB files

1. Update CSV files in `payload/tables/` directory.
2. Use command `make autofill` to complete the CSV files. The command is
   incomprehensive, you may need to debug the code all the way.
4. Use command `make devdb log-devdb` to create a Postgres instance and verify
   the payload CSVs.
5. If #4 passed, use command `make release` or `make pre-release` to build and
   release SQLite db file. **Credential required**
6. DB files will be stored in *build* folder, [GitHub releases
   page](https://github.com/hivdb/covid-drdb-payload/releases), and s3
   repository s3://cms.hivdb.org/covid-drdb.
