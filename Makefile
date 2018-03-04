THIS := $(realpath $(lastword $(MAKEFILE_LIST)))
HERE := $(shell dirname $(THIS))
IMAGE := "jekyll/jekyll:pages"
MOUNT := "$(HERE):/srv/jekyll"

.PHONY: build up down

build:
	docker run --rm -v $(MOUNT) $(IMAGE) jekyll build --verbose

up:
	docker run -d --rm -v $(MOUNT) -p 4000:4000 $(IMAGE) jekyll serve --watch --force_polling --verbose --incremental

down:
	docker ps | grep $(IMAGE) | awk '{ print $$1 }' | xargs docker kill
