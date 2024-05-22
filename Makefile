.PHONY: all docker

# Allow overriding the repo and tag name
DOCKER_NAME ?= fox

all: docker

docker:
	cp Dockerfile Dockerfile.tmp; \
	docker build --network host -t "${DOCKER_NAME}" . ; \

start:
	./docker-start.bash 1
