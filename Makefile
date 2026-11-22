-include .env
export

IMAGE ?= reuse-server:trixie

.PHONY: build push up down logs sh nginx-test backup restore-conf

build:
	docker build --network host --no-cache -t $(IMAGE) .

push:
	docker push $(IMAGE)

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=100 reuse-server

sh:
	docker compose exec reuse-server bash

nginx-test:
	docker compose exec reuse-server nginx -t

backup:
	@mkdir -p backup
	docker run --rm -v reuse-ts-state:/d -v "$(PWD)/backup":/b alpine \
	  tar czf /b/reuse-ts-state-$$(date +%F_%H%M).tgz -C /d .
	@ls -lh backup/
