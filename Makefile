PG_USR=maxtwo
PG_PWD=passwswsw
PG_INSTANCE=max_two_db
PG_DOCKER=postgres:15
TEST_TAG=maxtwo:test
DOCKER_NETWORK=maxtwonet

.PHONY: test
test: network test-db
	echo "Testing..."
	docker rmi $(TEST_TAG)
	docker build -f ./docker/Dockerfile-test -t $(TEST_TAG) .
	docker run --rm --network $(DOCKER_NETWORK) $(TEST_TAG)
	docker stop $(PG_INSTANCE)
	docker rm $(PG_INSTANCE)
	docker network rm $(DOCKER_NETWORK)

.PHONY: test-db
test-db:
	IS_TEST_DB=$(shell docker container inspect -f '{{.State.Running}}' $(PG_INSTANCE) ); \
	export IS_TEST_DB; \
	if [ $${IS_TEST_DB} = true ]; then \
		echo "ALREADY RUNNING"; \
	elif [ $${IS_TEST_DB} = false ]; then \
		echo "ALREADY EXISTS: STARTING"; \
		docker start $(PG_INSTANCE); \
	else \
		echo "STARTING NEW"; \
		docker run -d --network $(DOCKER_NETWORK) --name $(PG_INSTANCE) -p 5432:5432 \
	-e POSTGRES_USER=$(PG_USR) -e POSTGRES_PASSWORD=$(PG_PWD) $(PG_DOCKER); \
	fi
 
 .PHONY: network
 network:
	docker network create $(DOCKER_NETWORK)