#!/bin/bash

# Based on https://github.com/nicksp/dotfiles

# Symlink all the dotfiles to ~/
# As well as ~/bin

# Can be safely run multiple times

# Get the dotfiles directory's absolute path
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

YES_OVERRIDE=false
if [ "$1" == "-y" ]; then YES_OVERRIDE=true; fi

SUDO_CMD=""
if [ "$(id -u)" != "0" ]; then
  SUDO_CMD="sudo"
fi

##
# Utils
##

answer_is_yes() {
  [[ "$REPLY" =~ ^[Yy]$ ]] \
    && return 0 \
    || return 1
}

ask() {
  print_question "$1"
  read
}

ask_for_confirmation() {
  print_question "$1 (y/n) "
  read -n 1
  printf "\n"
}

cmd_exists() {
  [ -x "$(command -v "$1")" ] \
    && printf 0 \
    || printf 1
}

execute() {
  $1 &> /dev/null
  print_result $? "${2:-$1}"
}

get_answer() {
  printf "$REPLY"
}

get_os() {
  declare -r OS_NAME="$(uname -s)"
  local os=""

  if [ "$OS_NAME" == "Darwin" ]; then
    os="osx"
  elif [ "$OS_NAME" == "Linux" ] && [ -e "/etc/lsb-release" ]; then
    os="ubuntu"
  fi

  printf "%s" "$os"
}

is_git_repository() {
  [ "$(git rev-parse &>/dev/null; printf $?)" -eq 0 ] \
    && return 0 \
    || return 1
}

mkd() {
  if [ -n "$1" ]; then
    if [ -e "$1" ]; then
      if [ ! -d "$1" ]; then
        print_error "$1 - a file with the same name already exists!"
      else
        print_success "$1"
      fi
    else
      execute "mkdir -p $1" "$1"
    fi
  fi
}

print_success() {
  # Print output in green
  printf "\e[0;32m  [✔] $1\e[0m\n"
}

print_error() {
  # Print output in red
  printf "\e[0;31m  [✖] $1 $2\e[0m\n"
}

print_info() {
  # Print output in purple
  printf "\n\e[0;35m $1\e[0m\n\n"
}

print_question() {
  # Print output in yellow
  printf "\e[0;33m  [?] $1\e[0m"
}

print_result() {
  [ $1 -eq 0 ] \
    && print_success "$2" \
    || print_error "$2"

  [ "$3" == "true" ] && [ $1 -ne 0 ] \
    && exit
}

backup_existing_dotfiles() {
  dir_backup=~/dotfiles_old    # old dotfiles backup directory

  # Create dotfiles_old in homedir
  echo -n "Creating $dir_backup for backup of any existing dotfiles in ~..."
  mkdir -p $dir_backup
  echo "done"

  # Change to the dotfiles directory
  echo -n "Changing to the $DOTFILES_DIR directory..."
  cd $DOTFILES_DIR

  # # Back up any .files to dotfiles_old directory
  for i in ${FILES_TO_SYMLINK[@]}; do
    # echo "Moving any existing dotfiles from ~ to $dir_backup"
    mv ~/.${i#*/} ~/$dir_backup/
  done
}

install_zsh() {
  platform=$(uname)

  # Install zsh for Linux
  if [[ $platform == 'Linux' ]]; then
    if [[ -f /etc/redhat-release ]]; then
      ${SUDO_CMD} yum install zsh -y
    elif [[ -f /etc/debian_version ]]; then
      ${SUDO_CMD} apt-get install zsh -y
    fi
  # Install zsh for macOS
  elif [[ $platform == 'Darwin' ]]; then
    echo "We'll install zsh, then re-run this script!"
    brew install zsh
  fi
}

setup_zsh() {
  install_zsh
  chsh -s $(which zsh)

  # Test to see if zshell is installed.  If it is:
  if [ -f /bin/zsh -o -f /usr/bin/zsh ]; then
    # Install Oh My Zsh if it isn't already present
    if [[ ! -d $dir/oh-my-zsh/ ]]; then
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    else
      echo 'Zsh is not installed'
    fi
  fi
}

setup_symlinks() {
  declare -a FILES_TO_SYMLINK=(
    'shell/shell_aliases'
    'shell/shell_exports'
    'shell/shell_config'
    'shell/shell_functions'
    'shell/zshrc'
    'git/gitattributes'
    'git/gitconfig'
    'git/gitignore'
    'vim/vimrc'
    'vim/vimrc.bundles'
  )

  local i=''
  local sourceFile=''
  local targetFile=''

  echo "$1"

  for i in ${FILES_TO_SYMLINK[@]}; do
    sourceFile="$DOTFILES_DIR/$i"
    targetFile="$HOME/.$(printf "%s" "$i" | sed "s/.*\/\(.*\)/\1/g")"

    # link target file conditionally or always overwrite with -y argument
    if [ ! -e "$targetFile" ] || $YES_OVERRIDE; then
      execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
      print_success "$targetFile → $sourceFile"
    else
      ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
      if answer_is_yes; then
        rm -rf "$targetFile"
        execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
      else
        print_error "$targetFile → $sourceFile"
      fi
    fi
  done

  # Link oh-my-zsh theme
  ln -fs "$DOTFILES_DIR/shell/tyom.zsh-theme" "$HOME/.oh-my-zsh/themes"

  unset FILES_TO_SYMLINK
}

# --
# Begin setup
# --

# Warn user this script will overwrite current dotfiles
while true; do
  if $YES_OVERRIDE; then break; fi # accept -y argument to continue

  read -p "Warning: this will overwrite your current dotfiles. Continue? [y/n] " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

backup_existing_dotfiles

# Package managers & packages
if [ "$(uname)" == "Darwin" ]; then
  . "$DOTFILES_DIR/install/brew.sh"
  . "$DOTFILES_DIR/install/brew-cask.sh"
fi

. "$DOTFILES_DIR/install/node.sh"

# Vim plugins
echo 'Installing Vim pluigns…'
if [ -e "$HOME"/.vim/autoload/plug.vim ]; then
  echo 'Upgrading vim-plug'
  vim -E -s +PlugUpgrade +qa
else
  echo 'Downloading vim-plug'
  curl -fLo "$HOME"/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

echo 'Setting up zsh' && setup_zsh
echo 'Setting up symlinks' && setup_symlinks

# Vim bundles
vim -u "$HOME/.vimrc.bundles" +PlugUpdate +PlugClean! +qa

# Disable prompt when quitting iTerm
if [ "$(uname)" == "Darwin" ]; then
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
fi

# Launch
source "$HOME/.zshrc"

echo 'Dotfiles setup is done!'