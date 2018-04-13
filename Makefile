backup:
	./scripts/backup.sh

install:
	./scripts/setup.sh

brew:
	./scripts/install/brew.sh
	./scripts/install/brew-cask.sh

node:
	./scripts/install/node.sh

test:
	docker build -t dotfiles .
	docker run -it dotfiles zsh

.PHONY: backup install shell brew node vim test
