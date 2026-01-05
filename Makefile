IMAGE_NAME := dotfiles
CONTAINER_NAME := dotfiles-dev

# VARIANT support: use VARIANT=minimal for minimal image
# e.g., make docker-build VARIANT=minimal
VARIANT ?=
DOCKERFILE := Dockerfile$(if $(VARIANT),.$(VARIANT))
IMAGE := $(IMAGE_NAME)$(if $(VARIANT),-$(VARIANT))
CONTAINER := $(CONTAINER_NAME)$(if $(VARIANT),-$(VARIANT))
CMD_SUFFIX := $(if $(VARIANT),-$(VARIANT))

.DEFAULT_GOAL := help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install dotfiles on local machine
	./scripts/setup.sh

uninstall: ## Remove dotfiles symlinks
	./scripts/unstow.sh

brew: ## Install Homebrew packages
	./scripts/install/brew.sh
	./scripts/install/brew-cask.sh

docker-build: ## Build Docker image (use VARIANT=minimal for minimal)
	docker build -f $(DOCKERFILE) -t $(IMAGE) .

docker-shell: docker-build ## Start persistent shell (use VARIANT=minimal for minimal)
	@docker start -ai $(CONTAINER) 2>/dev/null || docker run -it --name $(CONTAINER) $(IMAGE) setup$(CMD_SUFFIX)

docker-test: docker-build ## Run setup and validation (use VARIANT=minimal for minimal)
	docker run --rm $(IMAGE) test$(CMD_SUFFIX)

docker-setup: docker-build ## Run setup and drop into shell (use VARIANT=minimal for minimal)
	docker run -it --rm $(IMAGE) setup$(CMD_SUFFIX)

docker-clean: ## Remove persistent Docker containers
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker rm -f $(CONTAINER_NAME)-minimal 2>/dev/null || true

docker-test-remote: ## Smoke test remote install from deployed URL
	docker build -f Dockerfile.remote-test -t $(IMAGE_NAME)-remote .
	docker run --rm $(IMAGE_NAME)-remote remote-test

docker-test-remote-local: ## Test remote install using local HTTP server
	docker build -f Dockerfile.remote-test -t $(IMAGE_NAME)-remote .
	docker run --rm $(IMAGE_NAME)-remote remote-test-local

.PHONY: help install uninstall brew docker-build docker-test docker-shell docker-setup docker-clean docker-test-remote docker-test-remote-local
