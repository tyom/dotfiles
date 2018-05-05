FROM ubuntu

RUN \
  apt-get update -qq && \
  apt-get upgrade -y && \
  apt-get install -y build-essential locales curl file vim git ruby python-setuptools sudo zsh && \
  localedef -i en_US -f UTF-8 en_US.UTF-8

COPY test/sudoers /etc/sudoers

RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo
RUN chmod 440 /etc/sudoers
USER docker

COPY . /home/docker/dotfiles
WORKDIR /home/docker/dotfiles

RUN YES_OVERRIDE=true make install
