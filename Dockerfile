# Dotfiles testing environment
FROM homebrew/brew:latest

ENV TERM=xterm-256color

# Install additional packages via apt (run as root temporarily)
USER root
RUN apt-get update -qq && \
  apt-get install -y vim locales zsh && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8

# Switch back to linuxbrew user
USER linuxbrew
ENV HOME=/home/linuxbrew

# Warm the Homebrew packages into a cached layer by running the real install
# script, so setup.sh's brew step finds everything present at test time and the
# run takes seconds instead of ~4 minutes. Running the script rather than a copy
# of its package list is the point: a copy drifts silently, and speed is the only
# thing this layer delivers. Its three files are copied on their own so the layer
# rebuilds when they change, not on every dotfile edit.
COPY --chown=linuxbrew:linuxbrew scripts/vars.sh ${HOME}/.dotfiles/scripts/
COPY --chown=linuxbrew:linuxbrew shell/utils.sh ${HOME}/.dotfiles/shell/
COPY --chown=linuxbrew:linuxbrew scripts/install/brew.sh ${HOME}/.dotfiles/scripts/install/
WORKDIR ${HOME}/.dotfiles
RUN bash scripts/install/brew.sh && rm -rf "$(brew --cache)"

# Copy dotfiles
COPY --chown=linuxbrew:linuxbrew . ${HOME}/.dotfiles

# Make entrypoint executable
RUN chmod +x scripts/docker-entrypoint.sh

# Flexible entrypoint: setup, validate, test, shell, or custom command
ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["shell"]
