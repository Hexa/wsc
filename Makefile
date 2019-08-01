.PHONY: all build release spec format

all: release

build:
	crystal build src/wsc.cr

release:
	crystal build src/wsc.cr --release

spec:
	crystal spec

format:
	crystal tool format src


.PHONY: ubuntu-16.04 ubuntu-18.04

BRANCH ?= develop
TAG := $(BRANCH)
TARGET = $@

ubuntu-16.04 ubuntu-18.04:
	docker image build -t wsc:$(TARGET) --build-arg branch=$(TAG) --build-arg os=$(TARGET) --no-cache --output . docker/
	tar czf wsc-$(TARGET).tar.gz wsc
	rm wsc
