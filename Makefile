THIS := $(realpath $(lastword $(MAKEFILE_LIST)))
HERE := $(shell dirname $(THIS))

.PHONY: build up down

build:
	docker run --rm -v "$(HERE):/srv/jekyll" "jekyll/builder:pages" jekyll build --verbose

up:
	docker run -d --rm -v "$(HERE):/srv/jekyll" -p 4000:4000 "jekyll/builder:pages" jekyll serve  --watch --force_polling --verbose --incremental

down:
	docker ps | grep "jekyll/builder:pages" | awk '{ print $$1 }' | xargs docker kill