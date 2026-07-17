# Checklist menu. Entries are "name|description|on/off" (on = pre-checked).
# Toggle by number, Enter confirms, q quits. Checked names land in CHECKED.
# YES_OVERRIDE checks everything; no tty keeps the defaults.
function multi_select {
  local title="$1" entry i n
  shift
  local names=() descs=() states=()
  for entry in "$@"; do
    names+=("${entry%%|*}")
    entry="${entry#*|}"
    descs+=("${entry%%|*}")
    states+=("${entry#*|}")
  done
  n=${#names[@]}

  if $YES_OVERRIDE || [[ ! -e /dev/tty ]]; then
    CHECKED=()
    for ((i = 0; i < n; i++)); do
      if $YES_OVERRIDE || [[ "${states[i]}" == "on" ]]; then
        CHECKED+=("${names[i]}")
      fi
    done
    return 0
  fi

  local drawn=false key box
  while true; do
    $drawn && printf "\r\e[%dA" $((n + 1))
    drawn=true
    print_step "$title"
    for ((i = 0; i < n; i++)); do
      box=' '
      [[ "${states[i]}" == "on" ]] && box='✔'
      printf '   \e[0;33m%d\e[0m [\e[0;32m%s\e[0m] \e[0;36m%-22s\e[0m %s\e[K\n' \
        $((i + 1)) "$box" "${names[i]}" "${descs[i]}"
    done
    printf " Toggle \e[0;33m1-%d\e[0m, \e[0;32mEnter\e[0m to install, \e[0;31mq\e[0m to quit \e[K" "$n"
    read -n 1 -s key </dev/tty || key=''
    case "$key" in
    '') echo; break ;;
    [qQ])
      echo
      exit 0
      ;;
    [1-9])
      i=$((key - 1))
      if ((i < n)); then
        [[ "${states[i]}" == "on" ]] && states[i]="off" || states[i]="on"
      fi
      ;;
    esac
  done

  CHECKED=()
  for ((i = 0; i < n; i++)); do
    [[ "${states[i]}" == "on" ]] && CHECKED+=("${names[i]}")
  done
}

function is_checked {
  local x
  for x in "${CHECKED[@]}"; do
    [[ "$x" == "$1" ]] && return 0
  done
  return 1
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

function print_skip {
  printf "\e[0;33m ○ $1\e[0m\n"
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
