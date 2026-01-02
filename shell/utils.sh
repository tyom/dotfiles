function continue_or_skip {
  local default="${2:-}"
  local prompt="(y/n)"

  if [[ "$default" == "y" ]]; then
    prompt="[Y/n]"
  elif [[ "$default" == "n" ]]; then
    prompt="[y/N]"
  fi

  print_question "$1 $prompt "

  # Handle YES_OVERRIDE (auto-accept all)
  if $YES_OVERRIDE; then
    echo
    return 0
  fi

  # Try interactive input via /dev/tty (works with curl | bash)
  if [[ -e /dev/tty ]]; then
    read -n 1 yn </dev/tty
    echo

    # Handle empty input (Enter) with default
    if [[ -z "$yn" || "$yn" == $'\n' ]]; then
      [[ "$default" == "y" ]] && return 0
      [[ "$default" == "n" ]] && return 1
    fi

    [[ "$yn" =~ ^[Yy]$ ]] && return 0
    [[ "$yn" =~ ^[Nn]$ ]] && return 1

    continue_or_skip "$1" "$default"
    return $?
  fi

  # Truly non-interactive: use defaults
  echo
  [[ "$default" == "y" ]] && return 0
  return 1
}

# yes to continue, no to exit
function continue_or_exit {
  local default="${2:-}"
  local prompt="(y/n)"

  if [[ "$default" == "y" ]]; then
    prompt="[Y/n]"
  elif [[ "$default" == "n" ]]; then
    prompt="[y/N]"
  fi

  print_question "$1 Continue? $prompt "

  # Handle YES_OVERRIDE (auto-accept all)
  if $YES_OVERRIDE; then
    echo
    return 0
  fi

  # Try interactive input via /dev/tty (works with curl | bash)
  if [[ -e /dev/tty ]]; then
    while true; do
      read -n 1 yn </dev/tty
      echo

      # Handle empty input (Enter) with default
      if [[ -z "$yn" ]]; then
        [[ "$default" == "y" ]] && break
        [[ "$default" == "n" ]] && exit
        echo " Please answer yes or no."
        continue
      fi

      case $yn in
      [Yy]*) break ;;
      [Nn]*) exit ;;
      *) echo " Please answer yes or no." ;;
      esac
    done
    return 0
  fi

  # Truly non-interactive: use defaults or exit
  echo
  if [[ "$default" == "y" ]]; then
    return 0
  else
    echo "Non-interactive mode requires default=y. Exiting."
    exit 1
  fi
}

function execute {
  $1 &>/dev/null
  print_result $? "${2:-$1}"
}

function print_step {
  printf "\e[0;36m ▶ \e[0m$1\n"
}

function print_question {
  printf "\e[0;33m ⁇ $1\e[0m"
}

function print_info {
  printf "\e[0;35m » $1\e[0m\n"
}

function print_info {
  printf "\e[0;35m » $1\e[0m\n"
}

function print_success {
  printf "\e[0;32m ✔ $1\e[0m\n"
}

function print_error {
  printf "\e[0;31m ✖ $1 $2\e[0m\n"
}

function print_warning {
  printf "\e[0;33m ⚠ $1\e[0m\n"
}

function print_result {
  [ $1 -eq 0 ] &&
    print_success "$2" ||
    print_error "$2"

  [ "$3" == "true" ] && [ $1 -ne 0 ] &&
    exit
}

function which_os {
  declare -r OS_NAME="$(uname -s)"
  local os=""

  if [ "$OS_NAME" == "Darwin" ]; then
    os="macos"
  elif [ "$OS_NAME" == "Linux" ]; then
    if [[ -f /etc/debian_version ]]; then
      os="debian"
    elif [[ -f /etc/redhat-release ]]; then
      os="redhat"
    else
      os="linux"
    fi
  fi
  printf $os
}

exists() {
  command -v $1 >/dev/null 2>&1
}
