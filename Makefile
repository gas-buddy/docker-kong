IMAGENAME = gasbuddy/kong-0.11

all: build

build:
	docker build --pull --no-cache -t $(IMAGENAME) .

clean:
	docker images | awk -F' ' '{if ($$1=="$(IMAGENAME)") print $$3}' | xargs -r docker rmi

test:
	docker run --rm -t -i -p 8000:8000 -p 8001:8001 $(IMAGENAME)

publish:
	docker push $(IMAGENAME)