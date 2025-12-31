# Dotfiles testing environment
FROM ubuntu:22.04

ENV TERM=xterm-256color
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages
RUN apt-get update -qq && \
  apt-get install -y git stow vim locales zsh curl unzip build-essential && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8

# Create non-root user
RUN useradd -m -s /bin/zsh dev
USER dev
ENV HOME=/home/dev

# Install Bun for testing Claude Code plugin
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="${HOME}/.bun/bin:${PATH}"

# Copy dotfiles
COPY --chown=dev:dev . ${HOME}/dotfiles
WORKDIR ${HOME}/dotfiles

# Make entrypoint executable
RUN chmod +x scripts/docker-entrypoint.sh

# Flexible entrypoint: setup, validate, test, shell, or custom command
ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["shell"]
