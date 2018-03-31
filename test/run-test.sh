#!/bin/bash

docker build -t dotfiles .
docker run -it dotfiles zsh