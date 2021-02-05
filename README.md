## DB update instruction

1. Update CSV files in `payload/tables/` directory.
2. Use command `make autofill` to complete the CSV files. The command is incomprehensive, you may need to debug the code all the way.
4. Use command `make devdb log-devdb` to create a Postgres instance and verify the payload CSVs.
5. If #4 passed, use command `make export-sqlite` to build SQLite db file.
