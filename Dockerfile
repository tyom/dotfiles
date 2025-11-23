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

# Copy dotfiles and install
COPY --chown=linuxbrew:linuxbrew . /home/linuxbrew/dotfiles
WORKDIR /home/linuxbrew/dotfiles

# Run installation (non-interactive mode)
RUN export YES_OVERRIDE=true && ./scripts/setup.sh

# Run validation
RUN ./scripts/validate.sh

# Default to zsh shell
CMD ["zsh"]
