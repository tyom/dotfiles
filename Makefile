install:
	./scripts/setup.sh

uninstall:
	./scripts/unstow.sh

brew:
	./scripts/install/brew.sh
	./scripts/install/brew-cask.sh

test:
	docker build -t dotfiles .
	docker run -it dotfiles zsh

.PHONY: install uninstall brew test
