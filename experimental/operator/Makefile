PROJECT = mmatejczyk-gke-dev
IMG = gcr.io/$(PROJECT)/operator
TAG = v0.0.2

all: push

.PHONY: build
build: cmd
	docker build --pull -t $(IMG):$(TAG) .
	docker tag $(IMG):$(TAG) $(IMG):latest
	@echo Built $(IMG):$(TAG) and tagged with latest

.PHONY: push
push: build
	docker push $(IMG):$(TAG)
	docker push $(IMG):latest
	@echo Pushed $(IMG) with :latest and :$(TAG) tags
