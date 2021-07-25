network:
	@docker network create -d bridge covid-drdb-network 2>/dev/null || true

builder:
	@docker build . -t hivdb/covid-drdb-builder:latest

docker-envfile:
	@test -f docker-envfile || (echo "Config file 'docker-envfile' not found, use 'docker-envfile.example' as a template to create it." && false)

inspect-builder: network docker-envfile
	@docker run --rm -it \
		--volume=$(shell pwd):/covid-drdb/ \
		--volume=$(shell dirname $$(pwd))/covid-drdb-payload:/covid-drdb/payload \
		--network=covid-drdb-network \
		--env-file ./docker-envfile \
   		hivdb/covid-drdb-builder:latest /bin/bash

release-builder:
	@docker push hivdb/covid-drdb-builder:latest

autofill:
	@docker run --rm -it \
		--volume=$(shell pwd):/covid-drdb/ \
		--volume=$(shell dirname $$(pwd))/covid-drdb-payload:/covid-drdb/payload \
   		hivdb/covid-drdb-builder:latest \
		pipenv run python -m drdb.entry autofill-payload payload/

export-sqlite: network
	@docker run \
		--rm -it \
		--volume=$(shell pwd):/covid-drdb/ \
		--volume=$(shell dirname $$(pwd))/covid-drdb-payload:/covid-drdb/payload \
		--network=covid-drdb-network \
		hivdb/covid-drdb-builder:latest \
		scripts/export-sqlite.sh

release: docker-envfile
	@docker run --rm -it \
		--volume=$(shell pwd):/covid-drdb/ \
		--volume=$(shell dirname $$(pwd))/covid-drdb-payload:/covid-drdb/payload \
		--env-file ./docker-envfile \
   		hivdb/covid-drdb-builder:latest \
		scripts/github-release.sh

devdb: network
	@docker run \
		--rm -it \
		--volume=$(shell pwd):/covid-drdb/ \
		--volume=$(shell dirname $$(pwd))/covid-drdb-payload:/covid-drdb/payload \
		hivdb/covid-drdb-builder:latest \
		scripts/export-sqls.sh
	$(eval volumes = $(shell docker inspect -f '{{ range .Mounts }}{{ .Name }}{{ end }}' covid-drdb-devdb))
	@mkdir -p local/sqls
	@docker rm -f covid-drdb-devdb 2>/dev/null || true
	@docker volume rm $(volumes) 2>/dev/null || true
	@docker run \
		-d --name=covid-drdb-devdb \
		-e POSTGRES_HOST_AUTH_METHOD=trust \
		-p 127.0.0.1:6543:5432 \
		--network=covid-drdb-network \
		--volume=$(shell pwd)/local/sqls:/docker-entrypoint-initdb.d \
		postgres:13.1

log-devdb:
	@docker logs -f covid-drdb-devdb

psql-devdb:
	@docker exec -it covid-drdb-devdb psql -U postgres

.PHONY: autofill network devdb *-devdb builder *-builder *-sqlite release
