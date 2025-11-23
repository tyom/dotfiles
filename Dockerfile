# Dotfiles testing environment
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color

RUN \
  apt-get update -qq && \
  apt-get upgrade -y && \
  apt-get install -y \
    build-essential \
    locales \
    curl \
    file \
    vim \
    git \
    stow \
    zsh && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8

# Setup non-root user
RUN useradd -m docker && echo "docker:docker" | chpasswd
USER docker

# Copy dotfiles and install
COPY --chown=docker:docker . /home/docker/dotfiles
WORKDIR /home/docker/dotfiles

# Run installation (non-interactive mode)
RUN YES_OVERRIDE=true make install

# Run validation
RUN ./scripts/validate.sh

# Default to zsh shell
CMD ["zsh"]
