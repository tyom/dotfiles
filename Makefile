IMAGE_NAME := dotfiles
CONTAINER_NAME := dotfiles-dev

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

docker-build: ## Build Docker test image
	docker build -t $(IMAGE_NAME) .

docker-shell: docker-build ## Start persistent shell in Docker (state preserved)
	@docker start -ai $(CONTAINER_NAME) 2>/dev/null || docker run -it --name $(CONTAINER_NAME) $(IMAGE_NAME)

docker-test: docker-build ## Run setup and validation in Docker
	docker run --rm $(IMAGE_NAME) test

docker-setup: docker-build ## Run setup and drop into shell
	docker run -it --rm $(IMAGE_NAME) setup

docker-clean: ## Remove persistent Docker container
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true

.PHONY: help install uninstall brew docker-build docker-test docker-shell docker-setup docker-clean
