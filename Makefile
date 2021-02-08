autofill:
	pipenv run python -m drdb.entry autofill-payload payload/

export-sqlite:
	@rm local/covid-drdb-$(shell date +"%Y-%m-%d").db 2>/dev/null || true
	@pipenv run db-to-sqlite "postgresql://postgres@localhost:6543/postgres" local/covid-drdb-$(shell date +"%Y-%m-%d").db --all
	@echo "Written local/covid-drdb-$(shell date +"%Y-%m-%d").db"

devdb:
	@./scripts/export-sqls.sh
	$(eval volumes = $(shell docker inspect -f '{{ range .Mounts }}{{ .Name }}{{ end }}' chiro-devdb))
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
