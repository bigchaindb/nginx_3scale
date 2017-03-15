# Targets:
# 	all: Cleans, formats src files, builds the code, builds the docker image
# 	clean: removes the binary and docker image
#	formatgo: Formats the src files
# 	buildgo: Builds the code
#	builddocker: Builds the code and docker image

GOCMD=go
GOVET=$(GOCMD) tool vet
GOINSTALL=$(GOCMD) install
GOFMT=gofmt -s -w

DOCKER_IMAGE_NAME?=bigchaindb/nginx_3scale
DOCKER_IMAGE_TAG?=0.1

PWD=$(shell pwd)
BINARY_PATH=$(PWD)/nginx_3scale_wrapper/
BINARY_NAME=nginx_3scale
MAIN_FILE = $(BINARY_PATH)/nginx_3scale.go
SRC_FILES = $(BINARY_PATH)/nginx_3scale.go

.PHONY: all

all: clean builddocker

clean:
	@echo "removing any pre-built binary";
	-@rm $(BINARY_PATH)/$(BINARY_NAME);
	@echo "remove any pre-built docker image";
	-@docker rmi $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG);

formatgo:
	$(GOFMT) $(SRC_FILES)

buildgo: formatgo
	$(shell cd $(BINARY_PATH) && \
		export GOPATH="$(BINARY_PATH)" && \
		export GOBIN="$(BINARY_PATH)" && \
		CGO_ENABLED=0 GOOS=linux $(GOINSTALL) -ldflags "-s" -a -installsuffix cgo $(MAIN_FILE))

builddocker: buildgo
	docker build \
		-t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) .;

vetgo:
	$(GOVET) .

