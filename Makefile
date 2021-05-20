autofill:
	pipenv run python -m drdb.entry autofill-payload payload/

export-sqlite:
	@rm local/covid-drdb-$(shell date +"%Y-%m-%d").db 2>/dev/null || true
	@pipenv run db-to-sqlite "postgresql://postgres@localhost:6543/postgres" local/covid-drdb-$(shell date +"%Y-%m-%d").db --all --no-index-fks
	@echo "Written local/covid-drdb-$(shell date +"%Y-%m-%d").db"
	@rm local/covid-drdb-latest.db 2>/dev/null || true
	@ln -vs covid-drdb-$(shell date +"%Y-%m-%d").db local/covid-drdb-latest.db
	@cp -v local/covid-drdb-$(shell date +"%Y-%m-%d").db ../chiro-cms/downloads/covid-drdb/$(shell date +"%Y%m%d").db
	@rm ../chiro-cms/downloads/covid-drdb/latest.db 2>/dev/null || true
	@ln -vs $(shell date +"%Y%m%d").db ../chiro-cms/downloads/covid-drdb/latest.db

	@cp local/covid-drdb-$(shell date +"%Y-%m-%d").db local/covid-drdb-$(shell date +"%Y-%m-%d")-slim.db
	@./scripts/make-slim-version.sh local/covid-drdb-$(shell date +"%Y-%m-%d")-slim.db
	@cp -v local/covid-drdb-$(shell date +"%Y-%m-%d")-slim.db ../chiro-cms/downloads/covid-drdb/$(shell date +"%Y%m%d")-slim.db
	@rm ../chiro-cms/downloads/covid-drdb/latest-slim.db 2>/dev/null || true
	@ln -vs $(shell date +"%Y%m%d")-slim.db ../chiro-cms/downloads/covid-drdb/latest-slim.db

devdb:
	@./scripts/export-sqls.sh
	$(eval volumes = $(shell docker inspect -f '{{ range .Mounts }}{{ .Name }}{{ end }}' covid-drdb-devdb))
	@mkdir -p local/sqls
	@docker rm -f covid-drdb-devdb 2>/dev/null || true
	@docker volume rm $(volumes) 2>/dev/null || true
	@docker run \
		-d --name=covid-drdb-devdb \
		-e POSTGRES_HOST_AUTH_METHOD=trust \
		-p 127.0.0.1:6543:5432 \
		--volume=$(shell pwd)/local/sqls:/docker-entrypoint-initdb.d \
		postgres:13.1

log-devdb:
	@docker logs -f covid-drdb-devdb

psql-devdb:
	@docker exec -it covid-drdb-devdb psql -U postgres

.PHONY: autofill devdb log-devdb psql-devdb
