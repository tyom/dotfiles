# Dotfiles testing environment
FROM homebrew/brew:latest

ENV TERM=xterm-256color

# Install additional packages via apt (run as root temporarily)
USER root
RUN apt-get update -qq && \
  apt-get install -y stow vim locales zsh && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8

# Switch back to linuxbrew user
USER linuxbrew
ENV HOME=/home/linuxbrew

# Copy dotfiles
COPY --chown=linuxbrew:linuxbrew . ${HOME}/dotfiles
WORKDIR ${HOME}/dotfiles

# Make entrypoint executable
RUN chmod +x scripts/docker-entrypoint.sh

# Flexible entrypoint: setup, validate, test, shell, or custom command
ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["shell"]
