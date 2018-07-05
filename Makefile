# TC Build container

# Set defaults that may be overridden in the buidrc
MY_TC_RELEASE := tis-r5-pike

UID := $(shell id -u)
USER := $(shell id -un)
MYUNAME := builder

BASE_CONTAINER := centos73
BASE_CONTAINER_TAG := local/dev-centos:7.3
BASE_DOCKERFILE := Dockerfile.centos73

TC_CONTAINER_NAME := $(USER)-centos-builder
TC_CONTAINER_TAG := local/$(USER)-stx-builder:7.3
TC_DOCKERFILE := Dockerfile.centos73.TC-builder

# Import the build config
NULL := $(shell bash -c "source buildrc; set | sed -E '/^[[:alnum:]_]+/s/=/:=/' | sed 's/^//' > .makeenv")
include .makeenv

# Base CentOS container

base-build:
	docker build \
		--ulimit core=0 \
		--network host \
		-t $(BASE_CONTAINER_TAG) \
		-f $(BASE_DOCKERFILE) \
		.

base-clean:
	docker image rm $(BASE_CONTAINER_TAG)

# TC builder container

build:
	docker build \
		--build-arg MYUID=$(UID) \
		--build-arg MYUNAME=$(MYUNAME) \
		--ulimit core=0 \
		--network host \
		-t $(TC_CONTAINER_TAG) \
		-f $(TC_DOCKERFILE) \
		.

clean:
	docker rm $(TC_CONTAINER_NAME) || true
	docker image rm $(TC_CONTAINER_TAG)

env:
	@echo "TC_DOCKERFILE=$(TC_DOCKERFILE)"
	@echo "TC_CONTAINER_NAME=$(TC_CONTAINER_NAME)"
	@echo "TC_CONTAINER_TAG=$(TC_CONTAINER_TAG)"
	@echo "SOURCE_REMOTE_NAME=$(SOURCE_REMOTE_NAME)"
	@echo "SOURCE_REMOTE_URI=$(SOURCE_REMOTE_URI)"
	@echo "HOST_MIRROR_DIR=$(HOST_MIRROR_DIR)"
	@echo "MY_TC_RELEASE=$(MY_TC_RELEASE)"
	@echo "LOCALDISK=${LOCALDISK}"
	@echo "GUEST_LOCALDISK=${GUEST_LOCALDISK}"

.PHONY: base-build base-clean build clean env
