.PHONY: all ubuntu-14.04 ubuntu-16.04 ubuntu-18.04

BRANCH = develop
TAG := $(BRANCH)
TARGET = $@

all: ubuntu-14.04 ubuntu-16.04 ubuntu-18.04

ubuntu-14.04 ubuntu-16.04 ubuntu-18.04:
	docker image build -t wsc:$(TARGET) --build-arg branch=$(TAG) --no-cache - < docker/Dockerfile-$(TARGET)
	docker container run -it --name wsc-$(TARGET) wsc:$(TARGET) crystal build src/wsc.cr --release
	docker container cp wsc-$(TARGET):wsc/wsc .
	tar czf wsc-$(TARGET).tar.gz wsc
	rm wsc
	docker container rm wsc-$(TARGET)
	docker image rm wsc:$(TARGET)
