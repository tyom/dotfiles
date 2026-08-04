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

# Warm the Homebrew downloads into a cached layer. setup.sh still runs its brew
# step at test time, it just finds everything present, which takes the run from
# ~4 minutes to seconds. This list mirrors scripts/install/brew.sh; if it drifts
# the test installs the missing formula itself, so it gets slower, never wrong.
# Retried once for the same reason brew.sh retries: a transient network drop
# fails the install, and brew skips what is already there so the retry is cheap.
RUN brew update && \
  (brew trust tyom/tap 2>/dev/null || true) && \
  PKGS="bat fzf git-delta herdr scmpuff tree wget tyom/tap/ungit" && \
  { brew install $PKGS || brew install $PKGS; } && \
  { brew install tyom/tap/repo-intel || brew install tyom/tap/repo-intel || true; } && \
  brew cleanup && rm -rf "$(brew --cache)"

# Copy dotfiles
COPY --chown=linuxbrew:linuxbrew . ${HOME}/.dotfiles
WORKDIR ${HOME}/.dotfiles

# Make entrypoint executable
RUN chmod +x scripts/docker-entrypoint.sh

# Flexible entrypoint: setup, validate, test, shell, or custom command
ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
CMD ["shell"]
